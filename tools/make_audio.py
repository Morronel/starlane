#!/usr/bin/env python3
"""Offline sound design + ambient music for Starlane.

Everything is synthesized from scratch (no samples), rendered at 44.1 kHz
stereo and written to assets/audio/*.ogg. Re-run after tweaking:

    python3 tools/make_audio.py            # all
    python3 tools/make_audio.py sfx        # just effects
    python3 tools/make_audio.py music      # just music
"""
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np
from scipy import signal

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
rng = np.random.default_rng(1234)


# ----------------------------------------------------------------------------
# helpers
# ----------------------------------------------------------------------------

def t_axis(dur):
    return np.arange(int(dur * SR)) / SR


def noise(dur):
    return rng.standard_normal(int(dur * SR))


def lp(x, fc, order=2):
    sos = signal.butter(order, min(fc, SR * 0.45), "low", fs=SR, output="sos")
    return signal.sosfilt(sos, x, axis=0)


def hp(x, fc, order=2):
    sos = signal.butter(order, fc, "high", fs=SR, output="sos")
    return signal.sosfilt(sos, x, axis=0)


def bp(x, lo, hi, order=2):
    sos = signal.butter(order, [lo, min(hi, SR * 0.45)], "band", fs=SR, output="sos")
    return signal.sosfilt(sos, x, axis=0)


def sweep_lp(x, f0, f1, block=256, curve="exp"):
    """Time-varying one-pole-ish lowpass via block-wise biquads with state."""
    n = len(x)
    out = np.zeros_like(x)
    zi = None
    nb = (n + block - 1) // block
    for b in range(nb):
        a = b / max(nb - 1, 1)
        fc = f0 * (f1 / f0) ** a if curve == "exp" else f0 + (f1 - f0) * a
        sos = signal.butter(2, min(max(fc, 20), SR * 0.45), "low", fs=SR, output="sos")
        if zi is None:
            zi = signal.sosfilt_zi(sos) * 0.0
        seg = x[b * block:(b + 1) * block]
        y, zi = signal.sosfilt(sos, seg, zi=zi)
        out[b * block:(b + 1) * block] = y
    return out


def mod_lp(x, fc_curve, block=512):
    """Lowpass with an arbitrary cutoff curve sampled per block."""
    n = len(x)
    out = np.zeros_like(x)
    zi = None
    for b in range(0, n, block):
        fc = float(fc_curve[min(b, len(fc_curve) - 1)])
        sos = signal.butter(2, min(max(fc, 30), SR * 0.45), "low", fs=SR, output="sos")
        if zi is None:
            zi = np.zeros((sos.shape[0], 2))
        y, zi = signal.sosfilt(sos, x[b:b + block], zi=zi)
        out[b:b + block] = y
    return out


def env_exp(dur, decay, attack=0.002):
    t = t_axis(dur)
    e = np.exp(-t * decay)
    a = np.clip(t / max(attack, 1e-5), 0, 1)
    return e * a


def adsr(n, a, d, s, r):
    a, d, r = int(a * SR), int(d * SR), int(r * SR)
    sus = max(n - a - d - r, 0)
    return np.concatenate([
        np.linspace(0, 1, a, endpoint=False),
        np.linspace(1, s, d, endpoint=False),
        np.full(sus, s),
        np.linspace(s, 0, r),
    ])[:n]


def chirp_phase(t, f0, f1, dur, kind="exp"):
    if kind == "exp":
        k = (f1 / f0) ** (1 / dur)
        return 2 * np.pi * f0 * (k ** t - 1) / np.log(k)
    k = (f1 - f0) / dur
    return 2 * np.pi * (f0 * t + 0.5 * k * t * t)


def saw(phase):
    return 2 * ((phase / (2 * np.pi)) % 1.0) - 1


def softclip(x, drive=1.0):
    return np.tanh(x * drive) / np.tanh(drive)


def stereo(x, width=0.0, delay_ms=0.0):
    """Mono -> stereo with optional Haas widening."""
    if x.ndim == 2:
        return x
    l = x.copy()
    r = x.copy()
    if delay_ms > 0:
        d = int(delay_ms * SR / 1000)
        r = np.concatenate([np.zeros(d), r[:-d]])
    if width:
        side = hp(noise(len(x) / SR) * 0.0 + x, 800) * width
        l = l + side
        r = r - side
    return np.stack([l, r], axis=1)


def pan(x, p):
    """p in -1..1, equal power."""
    a = (p + 1) * np.pi / 4
    return np.stack([x * np.cos(a), x * np.sin(a)], axis=1)


def make_ir(dur, decay, sr=SR, bright=6000, predelay=0.012, seed=7):
    r = np.random.default_rng(seed)
    n = int(dur * sr)
    t = np.arange(n) / sr
    env = np.exp(-t * decay)
    ir = r.standard_normal((n, 2)) * env[:, None]
    # darker tail: progressive lowpass by mixing a lowpassed copy in over time
    dark = lp(ir, bright * 0.25)
    mix = np.clip(t / dur * 1.5, 0, 1)[:, None]
    ir = ir * (1 - mix) + dark * mix
    ir = lp(ir, bright)
    pd = int(predelay * sr)
    ir = np.concatenate([np.zeros((pd, 2)), ir])
    ir /= np.sqrt(np.sum(ir ** 2) / 2)
    return ir


_IR_CACHE = {}


def reverb(x, wet=0.25, dur=2.0, decay=3.0, bright=7000, tail=True):
    key = (dur, decay, bright)
    if key not in _IR_CACHE:
        _IR_CACHE[key] = make_ir(dur, decay, bright=bright)
    ir = _IR_CACHE[key]
    x = stereo(x)
    if tail:
        x = np.concatenate([x, np.zeros((len(ir), 2))])
    w = np.stack([signal.fftconvolve(x[:, c], ir[:, c])[:len(x)] for c in range(2)], axis=1)
    return x * (1 - wet) + w * wet


def delay_pingpong(x, time_s, fb=0.4, wet=0.3, n_taps=6, damp=4000):
    x = stereo(x)
    d = int(time_s * SR)
    out = np.concatenate([x, np.zeros((d * n_taps, 2))])
    tap = x.copy()
    for i in range(1, n_taps + 1):
        tap = lp(tap, damp) * fb
        ch = i % 2
        seg = np.zeros_like(out)
        seg[d * i:d * i + len(tap), ch] = tap[:, 0] + tap[:, 1]
        out = out + seg * wet
    return out


def normalize(x, peak=0.89):
    m = np.max(np.abs(x))
    return x * (peak / m) if m > 0 else x


def fade(x, fin=0.002, fout=0.01):
    n = len(x)
    a, b = int(fin * SR), int(fout * SR)
    e = np.ones(n)
    if a:
        e[:a] = np.linspace(0, 1, a)
    if b:
        e[-b:] = np.linspace(1, 0, b)
    return x * (e[:, None] if x.ndim == 2 else e)


def write(name, x, peak=0.89, q=6):
    x = stereo(x)
    x = normalize(x, peak)
    os.makedirs(OUT, exist_ok=True)
    pcm = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
        tmp = f.name
    with wave.open(tmp, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    dst = os.path.join(OUT, name + ".ogg")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", str(q), dst], check=True)
    os.unlink(tmp)
    print(f"  {name}.ogg  {len(x) / SR:.2f}s")


def loopify(x, xfade_s):
    """Make a seamless loop by crossfading the tail into the head."""
    x = stereo(x)
    n = int(xfade_s * SR)
    body = x[:-n].copy()
    tail = x[-n:]
    ramp = np.linspace(0, 1, n)[:, None]
    body[:n] = body[:n] * ramp + tail * (1 - ramp)
    return body


def fm_bell(freq, dur, ratio=3.5, index=4.0, decay=2.5, idx_decay=4.0):
    t = t_axis(dur)
    mod = np.sin(2 * np.pi * freq * ratio * t) * index * np.exp(-t * idx_decay)
    car = np.sin(2 * np.pi * freq * t + mod)
    return car * env_exp(dur, decay, 0.003)


def add_at(x, b, o):
    m = min(len(b), len(x) - o)
    if m > 0:
        x[o:o + m] += b[:m]


def trim(x, thresh=0.0008):
    mag = np.max(np.abs(x), axis=1) if x.ndim == 2 else np.abs(x)
    idx = np.where(mag > thresh * np.max(mag))[0]
    if len(idx) == 0:
        return x
    end = min(len(x), idx[-1] + int(0.02 * SR))
    return fade(x[:end], 0.0, 0.02)


def note_hz(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


# ----------------------------------------------------------------------------
# sound effects
# ----------------------------------------------------------------------------

def sfx_laser_player():
    d = 0.42
    t = t_axis(d)
    # FM "pew" with fast pitch drop
    ph = chirp_phase(t, 2600, 380, 0.22)
    ph = np.where(t < 0.22, ph, ph[int(0.22 * SR) - 1] + 2 * np.pi * 380 * (t - 0.22))
    mod = np.sin(ph * 0.5) * 2.2 * np.exp(-t * 18)
    tone = np.sin(ph + mod) * np.exp(-t * 15)
    # bright click transient
    click = hp(noise(d), 3500) * np.exp(-t * 260) * 0.9
    # body thump
    thump = np.sin(chirp_phase(t, 220, 70, 0.08)) * np.exp(-t * 40) * 0.6
    # zap harmonic shimmer
    zap = saw(chirp_phase(t, 5200, 1600, 0.1)) * np.exp(-t * 55) * 0.18
    x = tone * 0.7 + click + thump + lp(zap, 9000)
    x = hp(x, 90)
    x = stereo(softclip(x, 1.4), delay_ms=6)
    x = reverb(x, wet=0.18, dur=1.2, decay=5, bright=6000)
    return fade(x, 0.0005, 0.08)


def sfx_laser_enemy():
    d = 0.5
    t = t_axis(d)
    ph = chirp_phase(t, 900, 160, 0.3)
    buzz = saw(ph) * 0.6 + np.sign(np.sin(ph * 0.5)) * 0.25
    buzz = lp(buzz, 3200) * np.exp(-t * 10)
    click = hp(noise(d), 2000) * np.exp(-t * 180) * 0.6
    sub = np.sin(chirp_phase(t, 140, 50, 0.12)) * np.exp(-t * 25) * 0.6
    x = softclip(buzz + click + sub, 2.0)
    x = reverb(stereo(x, delay_ms=9), wet=0.2, dur=1.2, decay=4.5, bright=5000)
    return fade(x, 0.0005, 0.08)


def sfx_explosion(big=False):
    d = 4.5 if big else 3.0
    t = t_axis(d)
    # crack
    crack = hp(noise(d), 1500) * np.exp(-t * 90) * 1.2
    # body: noise through falling lowpass, with slow decay
    body = sweep_lp(noise(d), 6000 if big else 5000, 120, block=512) * np.exp(-t * (1.4 if big else 2.2)) * 2.4
    # rumble
    rumble = lp(noise(d), 180) * np.exp(-t * (0.9 if big else 1.4)) * 5.0
    # sub boom
    sub = np.sin(chirp_phase(t, 75, 28, 1.2 if big else 0.8)) * np.exp(-t * (2.0 if big else 3.0)) * 1.3
    # crackles: sparse decaying clicks
    cr = np.zeros(len(t))
    nclick = 160 if big else 90
    pos = (rng.exponential(0.5 if big else 0.35, nclick) * SR).astype(int)
    for p in pos:
        if p < len(t) - 400:
            ln = rng.integers(40, 300)
            cr[p:p + ln] += rng.standard_normal(ln) * np.exp(-np.arange(ln) / (ln / 4)) * rng.uniform(0.2, 1.0)
    cr = hp(cr, 1200) * np.exp(-t * 1.2) * 0.5
    x = crack + body + rumble + sub + cr
    x = softclip(x, 1.6)
    l = x + hp(noise(d), 3000) * np.exp(-t * 6) * 0.05
    r = np.roll(x, int(0.011 * SR)) + hp(noise(d), 3000) * np.exp(-t * 6) * 0.05
    x = np.stack([l, r], axis=1)
    x = reverb(x, wet=0.35, dur=3.5, decay=1.8, bright=5000)
    return fade(x, 0.0005, 0.6)


def sfx_hit_shield():
    d = 0.6
    t = t_axis(d)
    zap = bp(noise(d), 1500, 7000) * np.exp(-t * 14)
    ring = np.sin(2 * np.pi * 1760 * t + 3 * np.sin(2 * np.pi * 37 * t)) * np.exp(-t * 9) * 0.5
    ring2 = np.sin(2 * np.pi * 2637 * t) * np.exp(-t * 12) * 0.25
    trem = 0.6 + 0.4 * np.sin(2 * np.pi * 28 * t)
    x = (zap * 0.7 + ring + ring2) * trem
    x += np.sin(chirp_phase(t, 400, 120, 0.1)) * np.exp(-t * 30) * 0.5
    x = reverb(stereo(x, delay_ms=7), wet=0.25, dur=1.5, decay=4, bright=8000)
    return fade(x, 0.0005, 0.1)


def sfx_hit_hull():
    d = 1.0
    t = t_axis(d)
    # modal metal: inharmonic partials
    partials = [(310, 1.0, 9), (797, 0.7, 12), (1213, 0.5, 15), (1871, 0.35, 18), (2650, 0.25, 22), (3477, 0.15, 25)]
    m = sum(a * np.sin(2 * np.pi * f * t + rng.uniform(0, 6)) * np.exp(-t * dc) for f, a, dc in partials)
    thud = lp(noise(d), 300) * np.exp(-t * 18) * 3
    crunch = bp(noise(d), 800, 5000) * np.exp(-t * 35) * 1.2
    x = softclip(m * 0.5 + thud + crunch, 1.8)
    x = reverb(stereo(x, delay_ms=5), wet=0.25, dur=1.6, decay=3.5, bright=6000)
    return fade(x, 0.0005, 0.15)


def sfx_engine_loop():
    d = 6.0
    t = t_axis(d + 1.0)
    brown = np.cumsum(noise(d + 1.0))
    brown = hp(brown, 20)
    brown /= np.max(np.abs(brown))
    rumble = lp(brown, 260) * 1.0
    hiss = bp(noise(d + 1.0), 1800, 6000) * 0.06
    # harmonic drone with slow beating
    drone = (np.sin(2 * np.pi * 46 * t) * 0.5 + np.sin(2 * np.pi * 92.4 * t) * 0.35 +
             np.sin(2 * np.pi * 138.2 * t) * 0.18 + saw(2 * np.pi * 46.2 * t) * 0.08)
    drone = lp(drone, 900)
    flutter = 1 + 0.08 * np.sin(2 * np.pi * 7.3 * t)
    x = (rumble + drone * 0.7) * flutter + hiss
    l = x
    r = np.roll(x, 300) + hp(noise(d + 1.0), 2500) * 0.02
    return loopify(np.stack([l, r], axis=1), 1.0)


def sfx_lane_loop():
    d = 6.0
    t = t_axis(d + 1.5)
    wind = bp(noise(d + 1.5), 300, 3500)
    mod = 0.7 + 0.3 * np.sin(2 * np.pi * 0.45 * t) * np.sin(2 * np.pi * 0.17 * t + 1)
    whistle = bp(noise(d + 1.5), 2200, 2600) * 0.6 * (0.5 + 0.5 * np.sin(2 * np.pi * 0.3 * t))
    hum = np.sin(2 * np.pi * 55 * t) * 0.25 + np.sin(2 * np.pi * 110.5 * t) * 0.12
    x = wind * mod + whistle + hum
    l = x
    r = np.roll(x, 900)
    return loopify(np.stack([l, r], axis=1), 1.5)


def whoosh(d, f0, f1, rise=True):
    t = t_axis(d)
    shape = np.sin(np.pi * np.clip(t / d, 0, 1)) ** (0.6 if rise else 1.5)
    n = noise(d)
    x = sweep_lp(n, f0, f1, block=256) * shape
    x += bp(n, 2000, 8000) * shape ** 3 * 0.15
    return x


def sfx_lane_enter():
    d = 2.2
    t = t_axis(d)
    w = whoosh(d, 250, 9000)
    rise = np.sin(chirp_phase(t, 80, 900, d)) * (t / d) ** 2 * 0.35
    hit_t = t - 1.25
    hit = np.where(hit_t > 0, np.sin(chirp_phase(np.maximum(hit_t, 0), 120, 35, 0.6)) * np.exp(-np.maximum(hit_t, 0) * 4), 0) * 1.4
    shimmer = sum(fm_bell(note_hz(n), d, ratio=2.0, index=1.2, decay=1.5) for n in (86, 90, 93, 98)) * 0.08
    shimmer = np.concatenate([np.zeros(int(1.2 * SR)), shimmer])[:len(t)]
    x = w * 0.9 + rise + hit + shimmer
    l = x
    r = np.roll(x, int(0.013 * SR))
    x = reverb(np.stack([l, r], 1), wet=0.3, dur=2.5, decay=2.5, bright=7000)
    return fade(x, 0.01, 0.5)


def sfx_lane_exit():
    d = 1.6
    t = t_axis(d)
    w = whoosh(d, 8000, 200, rise=False)
    fall = np.sin(chirp_phase(t, 700, 60, d)) * np.exp(-t * 2) * 0.3
    thump = np.sin(chirp_phase(t, 90, 40, 0.4)) * np.exp(-t * 8) * 0.9
    x = w + fall + thump
    x = reverb(stereo(x, delay_ms=12), wet=0.3, dur=2.0, decay=3, bright=6000)
    return fade(x, 0.003, 0.4)


def sfx_boost():
    d = 1.4
    t = t_axis(d)
    w = whoosh(d, 400, 5000)
    roar = lp(noise(d), 500) * np.clip(t / 0.15, 0, 1) * np.exp(-t * 1.5) * 2
    whine = np.sin(chirp_phase(t, 300, 1400, d)) * np.exp(-t * 2.5) * 0.15
    x = w + roar + whine
    return fade(reverb(stereo(x, delay_ms=9), wet=0.2, dur=1.5, decay=3), 0.003, 0.3)


def sfx_jump():
    d = 5.0
    t = t_axis(d)
    charge_d = 2.6
    tc = np.minimum(t, charge_d)
    charge = np.sin(chirp_phase(tc, 60, 1200, charge_d)) * (tc / charge_d) ** 2
    charge += np.sin(chirp_phase(tc, 90.5, 1810, charge_d)) * (tc / charge_d) ** 3 * 0.5
    charge = charge * (t < charge_d) * 0.4
    swell = sweep_lp(noise(d), 200, 12000, block=256) * np.clip(t / charge_d, 0, 1) ** 3 * (t < charge_d) * 0.8
    bt = np.maximum(t - charge_d, 0)
    boom = (np.sin(chirp_phase(bt, 110, 25, 1.5)) * np.exp(-bt * 1.8) * 1.6 +
            sweep_lp(noise(d), 9000, 150, block=512) * np.exp(-bt * 1.2) * 1.4) * (t >= charge_d)
    shimmer = sum(fm_bell(note_hz(n), d, 2.0, 2.0, 0.8, 1.5) for n in (74, 81, 86, 93, 98))
    shimmer = np.concatenate([np.zeros(int(charge_d * SR)), shimmer])[:len(t)] * 0.12
    x = softclip(charge + swell + boom + shimmer, 1.3)
    l = x
    r = np.roll(x, int(0.017 * SR))
    x = reverb(np.stack([l, r], 1), wet=0.4, dur=4.0, decay=1.4, bright=8000)
    return fade(x, 0.01, 0.8)


def ui_tick(f=2400, d=0.09, vol=1.0):
    t = t_axis(d)
    x = np.sin(2 * np.pi * f * t) * np.exp(-t * 60) * 0.6
    x += hp(noise(d), 5000) * np.exp(-t * 400) * 0.5
    x += np.sin(2 * np.pi * f * 1.5 * t) * np.exp(-t * 90) * 0.2
    return x * vol


def sfx_ui_click():
    x = ui_tick(2600, 0.12)
    return fade(reverb(stereo(x, delay_ms=3), wet=0.12, dur=0.6, decay=8, bright=9000), 0.0005, 0.03)


def sfx_ui_tab():
    a = ui_tick(1800, 0.1)
    b = ui_tick(2700, 0.14)
    x = np.zeros(int(0.25 * SR))
    x[:len(a)] += a
    x[int(0.05 * SR):int(0.05 * SR) + len(b)] += b * 0.8
    return fade(reverb(stereo(x, delay_ms=4), wet=0.15, dur=0.8, decay=6), 0.0005, 0.05)


def sfx_ui_buy():
    # satisfying coin "ka-ching": two FM bells + sparkle
    d = 1.4
    x = np.zeros(int(d * SR))
    for i, (n, dl) in enumerate([(88, 0.0), (95, 0.07), (100, 0.13)]):
        b = fm_bell(note_hz(n), d - dl, ratio=3.01, index=2.5, decay=4.5, idx_decay=8)
        o = int(dl * SR)
        add_at(x, b * (0.6 if i < 2 else 0.45), o)
    t = t_axis(d)
    x += hp(noise(d), 6000) * np.exp(-t * 30) * 0.15
    x += ui_tick(3000, d) * 0.5
    x = delay_pingpong(x, 0.11, fb=0.35, wet=0.25, n_taps=4, damp=6000)
    return fade(reverb(x, wet=0.22, dur=1.6, decay=3.5, bright=9000), 0.0005, 0.3)


def sfx_ui_upgrade():
    d = 2.2
    x = np.zeros(int(d * SR))
    for i, n in enumerate([74, 78, 81, 86, 90]):
        b = fm_bell(note_hz(n), d - i * 0.08, ratio=2.0, index=1.8, decay=2.2, idx_decay=3)
        o = int(i * 0.08 * SR)
        add_at(x, b * 0.4, o)
    t = t_axis(d)
    x += whoosh(d, 600, 9000) * 0.25 * np.exp(-t * 1.5)
    x += np.sin(chirp_phase(t, 70, 40, 0.5)) * np.exp(-t * 6) * 0.5
    x = delay_pingpong(x, 0.13, fb=0.35, wet=0.2, n_taps=4)
    return fade(reverb(x, wet=0.3, dur=2.5, decay=2.2, bright=9000), 0.001, 0.4)


def sfx_ui_error():
    d = 0.35
    t = t_axis(d)
    x = np.zeros(len(t))
    for o in (0.0, 0.13):
        tt = np.maximum(t - o, 0)
        x += saw(2 * np.pi * 180 * tt) * np.exp(-tt * 25) * (t >= o)
    x = lp(x, 1800) * 0.6
    return fade(reverb(stereo(x), wet=0.1, dur=0.6, decay=7), 0.0005, 0.05)


def sfx_ui_open():
    d = 1.0
    t = t_axis(d)
    x = whoosh(d, 300, 6000) * 0.4 * np.exp(-t * 2)
    for i, n in enumerate([81, 88]):
        b = fm_bell(note_hz(n), d - i * 0.06, 1.0, 0.8, 4.0)
        o = int(i * 0.06 * SR)
        add_at(x, b * 0.25, o)
    return fade(reverb(stereo(x, delay_ms=8), wet=0.25, dur=1.6, decay=3), 0.002, 0.3)


def sfx_dock_clamp():
    d = 2.0
    t = t_axis(d)
    x = np.zeros(len(t))
    for o, f in ((0.0, 160), (0.35, 120)):
        tt = np.maximum(t - o, 0)
        clang = sum(a * np.sin(2 * np.pi * f * m * tt) * np.exp(-tt * dc) for m, a, dc in ((1, 1, 10), (2.76, 0.5, 14), (5.4, 0.3, 20)))
        thud = lp(noise(d), 250) * np.exp(-tt * 20) * 2.5
        x += (clang * 0.5 + thud) * (t >= o)
    hiss_t = np.maximum(t - 0.6, 0)
    x += bp(noise(d), 3000, 9000) * np.exp(-hiss_t * 2.5) * (t >= 0.6) * np.clip(hiss_t / 0.05, 0, 1) * 0.35
    x = softclip(x, 1.5)
    return fade(reverb(stereo(x, delay_ms=10), wet=0.35, dur=2.2, decay=2.5, bright=5000), 0.0005, 0.3)


def sfx_launch():
    d = 2.5
    t = t_axis(d)
    roar = lp(noise(d), 400) * np.clip(t / 0.3, 0, 1) * np.exp(-t * 0.9) * 2.5
    w = whoosh(d, 300, 7000) * 0.6
    tone = np.sin(chirp_phase(t, 110, 330, d)) * np.exp(-t * 1.2) * 0.25
    clunk = lp(noise(d), 300) * np.exp(-t * 25) * 2
    x = softclip(roar + w + tone + clunk, 1.4)
    return fade(reverb(stereo(x, delay_ms=12), wet=0.3, dur=2.5, decay=2), 0.0005, 0.5)


def sfx_alarm():
    d = 0.9
    t = t_axis(d)
    x = np.zeros(len(t))
    for o in (0.0, 0.3):
        tt = np.maximum(t - o, 0)
        gate = (tt < 0.18) * (t >= o)
        x += (np.sin(2 * np.pi * 880 * tt) + 0.3 * np.sin(2 * np.pi * 1760 * tt)) * gate
    x = lp(x, 5000) * 0.5
    return fade(reverb(stereo(x), wet=0.15, dur=0.8, decay=5), 0.001, 0.05)


def sfx_mission_complete():
    d = 3.2
    x = np.zeros(int(d * SR))
    chord = [62, 69, 74, 78, 81, 86]
    for i, n in enumerate(chord):
        b = fm_bell(note_hz(n), d - i * 0.06, ratio=2.0, index=1.5, decay=1.2, idx_decay=2)
        o = int(i * 0.06 * SR)
        add_at(x, b * 0.3, o)
    t = t_axis(d)
    pad = sum(np.sin(2 * np.pi * note_hz(n) * t) for n in (50, 57, 62)) * adsr(len(t), 0.3, 0.5, 0.6, 1.5) * 0.15
    x = x + pad
    x = delay_pingpong(x, 0.18, fb=0.4, wet=0.25, n_taps=5)
    return fade(reverb(x, wet=0.35, dur=3.0, decay=1.8, bright=9000), 0.001, 0.6)


def sfx_target_lock():
    d = 0.25
    a = ui_tick(3200, 0.08, 0.7)
    b = ui_tick(4300, 0.1, 0.6)
    x = np.zeros(int(d * SR))
    x[:len(a)] += a
    x[int(0.06 * SR):int(0.06 * SR) + len(b)] += b
    return fade(stereo(x, delay_ms=2), 0.0005, 0.03)


def sfx_autofire_on():
    d = 0.4
    x = np.zeros(int(d * SR))
    for i, f in enumerate([1600, 2400, 3200]):
        a = ui_tick(f, 0.1, 0.7)
        o = int(i * 0.05 * SR)
        add_at(x, a, o)
    return fade(reverb(stereo(x), wet=0.15, dur=0.8, decay=6), 0.0005, 0.05)


def sfx_autofire_off():
    d = 0.4
    x = np.zeros(int(d * SR))
    for i, f in enumerate([3200, 2400, 1600]):
        a = ui_tick(f, 0.1, 0.7)
        o = int(i * 0.05 * SR)
        add_at(x, a, o)
    return fade(reverb(stereo(x), wet=0.15, dur=0.8, decay=6), 0.0005, 0.05)


def sfx_missile_launch():
    d = 1.6
    t = t_axis(d)
    pop = lp(noise(d), 900) * np.exp(-t * 30) * 2.0
    hiss = bp(noise(d), 1500, 9000) * np.clip(t / 0.04, 0, 1) * np.exp(-t * 1.6) * 0.8
    roar = lp(noise(d), 380) * np.clip(t / 0.06, 0, 1) * np.exp(-t * 2.2) * 1.6
    whine = np.sin(chirp_phase(t, 500, 1800, d)) * np.exp(-t * 2.8) * 0.12
    x = softclip(pop + hiss + roar + whine, 1.4)
    return fade(reverb(stereo(x, delay_ms=11), wet=0.22, dur=1.6, decay=3), 0.0005, 0.4)


def sfx_loot_pickup():
    d = 0.9
    x = np.zeros(int(d * SR))
    for i, n in enumerate([84, 88, 91, 96]):
        b = fm_bell(note_hz(n), 0.6, ratio=2.0, index=1.0, decay=6, idx_decay=8) * 0.35
        add_at(x, b, int(i * 0.045 * SR))
    t = t_axis(d)
    x += np.sin(chirp_phase(t, 300, 900, 0.12)) * np.exp(-t * 30) * 0.3
    return fade(reverb(stereo(x, delay_ms=4), wet=0.25, dur=1.0, decay=4, bright=9000), 0.0005, 0.2)


def sfx_autopilot_on():
    d = 1.1
    x = np.zeros(int(d * SR))
    for i, n in enumerate([69, 76, 81]):
        b = fm_bell(note_hz(n), 0.8, ratio=1.0, index=1.6, decay=4, idx_decay=5) * 0.4
        add_at(x, b, int(i * 0.09 * SR))
    t = t_axis(d)
    x += sweep_lp(noise(d), 300, 4000) * np.sin(np.pi * np.clip(t / 0.5, 0, 1)) * 0.12
    return fade(reverb(stereo(x, delay_ms=6), wet=0.3, dur=1.4, decay=3, bright=8000), 0.001, 0.3)


def sfx_autopilot_off():
    d = 0.9
    x = np.zeros(int(d * SR))
    for i, n in enumerate([81, 76, 69]):
        b = fm_bell(note_hz(n), 0.7, ratio=1.0, index=1.4, decay=5, idx_decay=6) * 0.35
        add_at(x, b, int(i * 0.08 * SR))
    return fade(reverb(stereo(x, delay_ms=6), wet=0.25, dur=1.2, decay=3.5, bright=7000), 0.001, 0.3)


def sfx_craft():
    """Workshop assembly: ratchets, a servo whirr, a heavy clamp and a bright chord."""
    d = 2.6
    t = t_axis(d)
    x = np.zeros(len(t))
    for k in range(7):
        o = 0.05 + k * 0.08
        tt = np.maximum(t - o, 0)
        click = bp(noise(d), 2500, 9000) * np.exp(-tt * 140) * (t >= o) * 0.7
        tick = np.sin(2 * np.pi * (1800 + k * 120) * tt) * np.exp(-tt * 90) * (t >= o) * 0.25
        x += click + tick
    servo_t = np.clip((t - 0.2) / 0.7, 0, 1)
    servo = saw(chirp_phase(t, 180, 520, 0.9)) * np.sin(np.pi * servo_t) * (t < 0.9) * 0.08
    x += lp(servo, 2500)
    ct = np.maximum(t - 0.95, 0)
    clamp = (sum(a * np.sin(2 * np.pi * 140 * m * ct) * np.exp(-ct * dc) for m, a, dc in ((1, 1, 9), (2.76, 0.5, 13), (5.4, 0.25, 18))) * 0.5
             + lp(noise(d), 260) * np.exp(-ct * 22) * 2.2) * (t >= 0.95)
    x += clamp
    chord = np.zeros(len(t))
    for i, n in enumerate([74, 78, 81, 86, 90]):
        b = fm_bell(note_hz(n), d - 1.1, ratio=2.0, index=1.6, decay=1.4, idx_decay=2.2) * 0.22
        add_at(chord, b, int((1.05 + i * 0.05) * SR))
    x = softclip(x + chord, 1.3)
    return fade(reverb(stereo(x, delay_ms=9), wet=0.3, dur=2.4, decay=2.2, bright=8000), 0.0005, 0.5)


def sfx_equip():
    d = 1.0
    t = t_axis(d)
    slide = bp(noise(d), 600, 3000) * np.sin(np.pi * np.clip(t / 0.25, 0, 1)) * (t < 0.25) * 0.3
    ct = np.maximum(t - 0.22, 0)
    lock = (np.sin(2 * np.pi * 220 * ct) * np.exp(-ct * 18) * 0.6 + np.sin(2 * np.pi * 607 * ct) * np.exp(-ct * 25) * 0.3
            + lp(noise(d), 400) * np.exp(-ct * 35) * 1.8) * (t >= 0.22)
    beep = np.sin(2 * np.pi * 2600 * np.maximum(t - 0.45, 0)) * ((t > 0.45) & (t < 0.52)) * 0.15
    x = softclip(slide + lock + beep, 1.3)
    return fade(reverb(stereo(x, delay_ms=7), wet=0.2, dur=1.0, decay=4), 0.0005, 0.2)


def sfx_lane_merge():
    d = 1.4
    t = t_axis(d)
    w = whoosh(d, 400, 8000) * 0.8
    thump = np.sin(chirp_phase(t, 140, 40, 0.5)) * np.exp(-t * 6) * 0.9
    shimmer = sum(fm_bell(note_hz(n), d, ratio=2.0, index=1.0, decay=2.0) for n in (81, 88, 93)) * 0.07
    x = w + thump + shimmer
    return fade(reverb(stereo(x, delay_ms=13), wet=0.3, dur=2.0, decay=2.8, bright=7000), 0.005, 0.4)


SFX = {
    "laser_player": (sfx_laser_player, 0.8),
    "laser_enemy": (sfx_laser_enemy, 0.8),
    "explosion": (lambda: sfx_explosion(False), 0.95),
    "explosion_big": (lambda: sfx_explosion(True), 0.95),
    "hit_shield": (sfx_hit_shield, 0.8),
    "hit_hull": (sfx_hit_hull, 0.9),
    "engine_loop": (sfx_engine_loop, 0.8),
    "lane_loop": (sfx_lane_loop, 0.8),
    "lane_enter": (sfx_lane_enter, 0.9),
    "lane_exit": (sfx_lane_exit, 0.9),
    "boost": (sfx_boost, 0.85),
    "jump": (sfx_jump, 0.95),
    "ui_click": (sfx_ui_click, 0.7),
    "ui_tab": (sfx_ui_tab, 0.7),
    "ui_buy": (sfx_ui_buy, 0.8),
    "ui_upgrade": (sfx_ui_upgrade, 0.85),
    "ui_error": (sfx_ui_error, 0.7),
    "ui_open": (sfx_ui_open, 0.75),
    "dock_clamp": (sfx_dock_clamp, 0.9),
    "launch": (sfx_launch, 0.9),
    "alarm": (sfx_alarm, 0.7),
    "mission_complete": (sfx_mission_complete, 0.85),
    "target_lock": (sfx_target_lock, 0.6),
    "autofire_on": (sfx_autofire_on, 0.7),
    "autofire_off": (sfx_autofire_off, 0.7),
    "missile_launch": (sfx_missile_launch, 0.85),
    "loot_pickup": (sfx_loot_pickup, 0.7),
    "autopilot_on": (sfx_autopilot_on, 0.7),
    "autopilot_off": (sfx_autopilot_off, 0.7),
    "craft": (sfx_craft, 0.85),
    "equip": (sfx_equip, 0.8),
    "lane_merge": (sfx_lane_merge, 0.85),
}


# --- 0.12 the road ----------------------------------------------------------

def sfx_radio_tune():
    d = 0.55
    t = t_axis(d)
    st = bp(noise(d), 900, 5000) * (0.5 + 0.5 * np.sin(2 * np.pi * 11 * t) ** 2) * np.exp(-t * 3)
    wh = np.sin(chirp_phase(t, 2400, 600, d)) * 0.12 * np.exp(-t * 4)
    return fade(stereo(st * 0.6 + wh, delay_ms=7), 0.003, 0.08)


def sfx_photo():
    d = 0.35
    t = t_axis(d)
    c1 = hp(noise(d), 3000) * np.exp(-t * 90)
    c2 = np.roll(hp(noise(d), 2000) * np.exp(-t * 60), int(0.09 * SR)) * 0.8
    whir = np.sin(2 * np.pi * (900 + 400 * t) * t) * np.exp(-((t - 0.2) * 14) ** 2) * 0.15
    return fade(stereo(c1 + c2 + whir), 0.0, 0.05)


def sfx_event_ping():
    x = sum(fm_bell(note_hz(n), 1.6, ratio=2.0, index=1.2, decay=2.6) * g for n, g in ((76, 0.5), (83, 0.35)))
    x2 = np.concatenate([np.zeros(int(0.16 * SR)), fm_bell(note_hz(88), 1.4, ratio=2.0, index=1.0, decay=3) * 0.35])
    y = np.zeros(max(len(x), len(x2)))
    y[:len(x)] += x
    y[:len(x2)] += x2
    return reverb(stereo(y, delay_ms=9), wet=0.3, dur=1.6, decay=3.0)


def sfx_scan():
    d = 1.4
    t = t_axis(d)
    sweep = np.sin(chirp_phase(t, 300, 2400, d)) * 0.25 * np.sin(np.pi * t / d)
    blips = np.sin(2 * np.pi * 1800 * t) * (np.sin(2 * np.pi * 7 * t) > 0.92) * 0.2
    return fade(stereo(sweep + blips, delay_ms=11), 0.01, 0.1)


def sfx_cruise_on():
    d = 1.2
    t = t_axis(d)
    x = np.sin(chirp_phase(t, 70, 160, d)) * 0.6 * np.exp(-t * 1.5) + lp(noise(d), 900) * 0.3 * np.sin(np.pi * t / d)
    return fade(stereo(x, delay_ms=15), 0.02, 0.2)


def sfx_kaching():
    a = fm_bell(note_hz(84), 0.9, ratio=3.0, index=2.0, decay=4)
    b = np.concatenate([np.zeros(int(0.08 * SR)), fm_bell(note_hz(91), 1.1, ratio=3.0, index=2.0, decay=3.5)])
    coins = hp(noise(0.5), 5000) * np.exp(-t_axis(0.5) * 9) * 0.25
    y = np.zeros(len(b))
    y[:len(a)] += a * 0.6
    y += b * 0.6
    y[:len(coins)] += coins
    return reverb(stereo(y, delay_ms=6), wet=0.2, dur=1.0, decay=4.0)


def sfx_dice():
    d = 0.9
    out = np.zeros(int(d * SR))
    r = np.random.default_rng(3)
    tpos = 0.0
    for k in range(7):
        c = bp(noise(0.05), 1500, 6000) * np.exp(-t_axis(0.05) * 80) * (0.9 - k * 0.1)
        add_at(out, c, int(tpos * SR))
        tpos += 0.05 + k * 0.03 + r.uniform(0, 0.03)
    return stereo(out, delay_ms=5)


def sfx_cheers():
    d = 1.6
    t = t_axis(d)
    clink = sum(fm_bell(f, 1.0, ratio=2.76, index=1.5, decay=5) for f in (2200, 2650)) * 0.3
    crowd = bp(noise(d), 300, 2500) * np.sin(np.pi * t / d) ** 0.5 * 0.35
    y = crowd.copy()
    y[:len(clink)] += clink
    return reverb(stereo(y, delay_ms=12), wet=0.25, dur=1.2, decay=3.5)


SFX.update({
    "radio_tune": (sfx_radio_tune, 0.6),
    "photo": (sfx_photo, 0.7),
    "event_ping": (sfx_event_ping, 0.75),
    "scan": (sfx_scan, 0.6),
    "cruise_on": (sfx_cruise_on, 0.8),
    "kaching": (sfx_kaching, 0.8),
    "dice": (sfx_dice, 0.7),
    "cheers": (sfx_cheers, 0.7),
})


# ----------------------------------------------------------------------------
# music
# ----------------------------------------------------------------------------

def supersaw(freq, n, voices=5, detune=0.012, seed=0):
    r = np.random.default_rng(seed)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for v in range(voices):
        dt = 1 + detune * (v - (voices - 1) / 2) / ((voices - 1) / 2 if voices > 1 else 1)
        out += saw(2 * np.pi * freq * dt * t + r.uniform(0, 2 * np.pi))
    return out / voices


def pad_voice(freq, n, seed, bright=1.0):
    x = supersaw(freq, n, voices=5, detune=0.01, seed=seed) * 0.7
    t = np.arange(n) / SR
    x += np.sin(2 * np.pi * freq * t) * 0.5          # body
    x += np.sin(2 * np.pi * freq * 2.001 * t) * 0.12  # octave sheen
    return x


def render_music(name, length_s, bpm_free_chords, chord_len, bells_scale, root_drone, colors):
    """Generic ambient renderer.

    bpm_free_chords: list of chords (lists of midi notes), each chord_len seconds,
    cycled to fill length_s exactly (so the track loops).
    """
    tail = 8.0
    n = int((length_s + tail) * SR)
    L = np.zeros(n)
    R = np.zeros(n)
    t_all = np.arange(n) / SR
    n_chords = int(round(length_s / chord_len))
    xf = 4.0  # chord crossfade seconds

    # --- pads
    for ci in range(n_chords + 1):
        chord = bpm_free_chords[ci % len(bpm_free_chords)]
        start = ci * chord_len - xf
        seg_len = chord_len + 2 * xf
        s0 = int(max(start, 0) * SR)
        s1 = int(min(start + seg_len, length_s + tail) * SR)
        if s1 <= s0:
            continue
        m = s1 - s0
        env = adsr(int(seg_len * SR), xf, 0.5, 1.0, xf)
        env = env[int(max(-start, 0) * SR):][:m]
        for vi, note in enumerate(chord):
            v = pad_voice(note_hz(note), m, seed=ci * 31 + vi)
            p = ((vi / max(len(chord) - 1, 1)) * 2 - 1) * 0.7
            a = (p + 1) * np.pi / 4
            gain = 0.16 * (1.0 if note < 72 else 0.6)
            L[s0:s1] += v * env * gain * np.cos(a)
            R[s0:s1] += v * env * gain * np.sin(a)
    # slow filter motion on pads
    cutoff = colors["pad_cut"] * (1 + 0.6 * np.sin(2 * np.pi * t_all / colors["filter_period"]) ** 2)
    L = mod_lp(L, cutoff)
    R = mod_lp(R, cutoff)

    # --- drone / sub
    drone = (np.sin(2 * np.pi * note_hz(root_drone) * t_all) * 0.35 +
             np.sin(2 * np.pi * note_hz(root_drone + 12) * 1.002 * t_all) * 0.12)
    drone *= 0.75 + 0.25 * np.sin(2 * np.pi * t_all / 23.0)
    L += drone * 0.5
    R += drone * 0.5

    # --- airy noise wash
    wash = bp(rng.standard_normal(n), 700, 4000) * 0.012
    wash *= 0.6 + 0.4 * np.sin(2 * np.pi * t_all / 17.0) ** 2
    L += wash
    R += np.roll(wash, 2000)

    # --- sparse bells / plucks with ping-pong delay
    bells = np.zeros((n, 2))
    r = np.random.default_rng(99)
    tpos = 2.0
    while tpos < length_s - 1.0:
        ci = int(tpos // chord_len) % len(bpm_free_chords)
        chord = bpm_free_chords[ci]
        pool = [x for x in bells_scale if (x % 12) in {c % 12 for c in chord}] or bells_scale
        note = int(r.choice(pool))
        dur = 4.0
        b = fm_bell(note_hz(note), dur, ratio=colors["bell_ratio"], index=colors["bell_index"], decay=1.6, idx_decay=2.5)
        b = lp(b, 7000) * r.uniform(0.05, 0.11)
        p = r.uniform(-0.8, 0.8)
        s0 = int(tpos * SR)
        s1 = min(s0 + len(b), n)
        bells[s0:s1] += pan(b[:s1 - s0], p)
        tpos += float(r.choice(colors["bell_gaps"]))
    bells = delay_pingpong(bells, colors["delay"], fb=0.45, wet=0.45, n_taps=6, damp=3500)[:n]

    mix = np.stack([L, R], axis=1) + bells
    mix = hp(mix, 28)
    # big hall
    mix = reverb(mix, wet=colors["verb_wet"], dur=7.0, decay=0.8, bright=6000, tail=False)
    # wrap tail into the head for a seamless loop
    body_n = int(length_s * SR)
    body = mix[:body_n].copy()
    tail_part = mix[body_n:]
    body[:len(tail_part)] += tail_part
    # gentle glue
    body = softclip(body * 1.1, 1.2)
    return body


def music_flight():
    # D dorian/lydian drift: Dm9 - Bbmaj7#11 - Gm9 - Asus4 - Fmaj7 - Cadd9/E
    chords = [
        [50, 57, 60, 64, 69],
        [46, 53, 57, 62, 64],
        [43, 50, 53, 57, 62],
        [45, 52, 57, 62, 64],
        [41, 48, 52, 57, 64],
        [40, 48, 55, 62, 67],
    ]
    scale = [74, 76, 77, 79, 81, 84, 86, 88, 89, 91, 93]
    colors = dict(pad_cut=1400, filter_period=37.0, bell_ratio=3.5, bell_index=2.2,
                  bell_gaps=[1.5, 2.0, 3.0, 3.0, 4.5, 6.0], delay=0.42, verb_wet=0.45)
    return render_music("flight", 144.0, chords, 12.0, scale, 38, colors)


def music_station():
    # warm, hopeful: Fmaj9 - Am7 - Dm11 - Bbmaj9 - Csus2 - Gm9
    chords = [
        [41, 48, 52, 55, 60, 67],
        [45, 52, 55, 60, 64],
        [38, 45, 50, 55, 60],
        [46, 53, 57, 60, 65],
        [48, 55, 60, 62, 67],
        [43, 50, 53, 57, 62],
    ]
    scale = [72, 74, 76, 77, 79, 81, 84, 86, 88]
    colors = dict(pad_cut=2000, filter_period=29.0, bell_ratio=1.0, bell_index=1.4,
                  bell_gaps=[0.75, 1.0, 1.5, 1.5, 2.25, 3.0], delay=0.375, verb_wet=0.4)
    return render_music("station", 120.0, chords, 10.0, scale, 29, colors)


def drum_kick(dur=0.6):
    t = t_axis(dur)
    body = np.sin(chirp_phase(t, 150, 42, 0.12)) * np.exp(-t * 7)
    click = lp(noise(dur), 3000) * np.exp(-t * 120) * 0.5
    return softclip(body * 1.3 + click, 1.5)


def drum_tom(f, dur=0.9):
    t = t_axis(dur)
    body = np.sin(chirp_phase(t, f * 1.6, f, 0.08)) * np.exp(-t * 5)
    skin = bp(noise(dur), f * 2, f * 8) * np.exp(-t * 25) * 0.6
    return softclip(body + skin, 1.4)


def drum_snare(dur=0.5):
    t = t_axis(dur)
    tone = np.sin(2 * np.pi * 190 * t) * np.exp(-t * 22) * 0.6
    rattle = bp(noise(dur), 1500, 9000) * np.exp(-t * 13)
    return tone + rattle


def drum_hat(dur=0.12, open_=False):
    t = t_axis(dur)
    return hp(noise(dur), 7000) * np.exp(-t * (14 if open_ else 60))


def brass_stab(freqs, dur):
    n = int(dur * SR)
    t = np.arange(n) / SR
    x = sum(supersaw(f, n, voices=5, detune=0.008, seed=int(f)) for f in freqs) / len(freqs)
    env = adsr(n, 0.015, 0.12, 0.55, 0.12)
    cut = 600 + 4200 * np.exp(-t * 7)
    return mod_lp(x * env, cut, block=256)


def music_combat():
    """Driving 132 BPM combat loop: A minor, toms + kick, 16th bass ostinato, brass stabs, risers."""
    bpm = 132.0
    beat = 60.0 / bpm
    bars = 48
    length_s = bars * 4 * beat
    tail = 6.0
    n = int((length_s + tail) * SR)
    mix = np.zeros((n, 2))
    r = np.random.default_rng(5)

    # chord roots per bar (2 bars each): Am F G Em | Dm Bb C E
    prog = [(45, [57, 60, 64]), (41, [57, 60, 65]), (43, [55, 59, 62]), (40, [55, 59, 64]),
            (38, [57, 62, 65]), (46, [58, 62, 65]), (48, [55, 60, 64]), (40, [56, 59, 64])]

    def chord_at(bar):
        return prog[(bar // 2) % len(prog)]

    kick = drum_kick()
    snare = drum_snare()
    hat = drum_hat()
    ohat = drum_hat(0.4, True)
    toms = [drum_tom(f) for f in (70, 95, 130)]

    def put(sig, tsec, gain, p=0.0):
        o = int(tsec * SR)
        st = pan(sig * gain, p)
        m = min(len(st), n - o)
        if m > 0:
            mix[o:o + m] += st[:m]

    for bar in range(bars):
        t0 = bar * 4 * beat
        section = (bar // 8) % 6  # 0 intro-ish, then build
        intense = section >= 1
        # kick: four on the floor with a syncopated push
        for b in range(4):
            put(kick, t0 + b * beat, 0.9)
        if intense:
            put(kick, t0 + 3.5 * beat, 0.55)
        # snare / clap backbeat
        if intense:
            for b in (1, 3):
                put(snare, t0 + b * beat, 0.42, 0.1)
        # hats: 16ths with accents
        for k in range(16):
            acc = 0.22 if k % 4 == 2 else 0.11
            if not intense and k % 2 == 1:
                continue
            put(hat, t0 + k * beat / 4, acc, 0.35 if k % 2 else -0.25)
        if intense:
            put(ohat, t0 + 1.5 * beat, 0.12, 0.4)
            put(ohat, t0 + 3.5 * beat, 0.12, -0.4)
        # taiko pattern every other bar, fills every 8th bar
        if bar % 2 == 1:
            for k, (pos, ti) in enumerate([(0.0, 2), (0.75, 1), (1.5, 1), (2.0, 0), (2.5, 0), (3.0, 1)]):
                put(toms[ti], t0 + pos * beat, 0.5, (ti - 1) * 0.4)
        if bar % 8 == 7:
            for k in range(8):
                put(toms[2 - (k % 3)], t0 + (2 + k * 0.25) * beat, 0.45 + k * 0.04, (k % 3 - 1) * 0.5)

    # 16th-note bass ostinato
    bass = np.zeros(n)
    patt = [0, 0, 12, 0, 0, 7, 0, 12, 0, 0, 12, 0, 10, 0, 7, 0]
    for bar in range(bars):
        root, _ = chord_at(bar)
        for k in range(16):
            ts = bar * 4 * beat + k * beat / 4
            dur = beat / 4 * 0.9
            m = int(dur * SR)
            tt = np.arange(m) / SR
            f = note_hz(root - 12 + patt[k])
            v = saw(2 * np.pi * f * tt) * 0.6 + np.sin(2 * np.pi * f * 0.5 * tt) * 0.6
            env = np.exp(-tt * 14) * (1 - np.exp(-tt * 400))
            cut = 300 + 1600 * np.exp(-tt * 20) * (1.0 if k % 4 == 0 else 0.6)
            v = mod_lp(v * env, cut, block=64)
            add_at(bass, v * (1.0 if k % 4 == 0 else 0.75), int(ts * SR))
    bass = softclip(bass * 1.4, 1.3)
    mix += np.stack([bass, bass], 1) * 0.38

    # dark string pad
    pad = np.zeros((n, 2))
    for ci in range(bars // 2):
        root, notes = chord_at(ci * 2)
        ts = ci * 8 * beat
        seg = 8 * beat + 0.5
        m = int(seg * SR)
        env = adsr(m, 0.6, 0.5, 0.8, 0.8)
        for vi, nt in enumerate(notes + [root + 12]):
            v = supersaw(note_hz(nt), m, voices=5, detune=0.009, seed=ci * 7 + vi)
            v = lp(v, 1600) * env * 0.11
            p = (vi / 3.0) * 1.4 - 0.7
            o = int(ts * SR)
            mm = min(m, n - o)
            pad[o:o + mm] += pan(v[:mm], p)
    mix += pad

    # brass stabs on the off-beats of every second bar (from bar 8)
    for bar in range(8, bars, 2):
        root, notes = chord_at(bar)
        for pos in (0.0, 0.75, 1.5):
            st = brass_stab([note_hz(x) for x in notes], beat * 0.5)
            put(st, bar * 4 * beat + pos * beat, 0.32, r.uniform(-0.3, 0.3))
    # arpeggio lead in the second half
    for bar in range(24, bars):
        root, notes = chord_at(bar)
        arp = notes + [notes[0] + 12, notes[1] + 12]
        for k in range(8):
            nt = arp[(k * 2 + bar) % len(arp)] + 12
            b = fm_bell(note_hz(nt), 0.45, ratio=3.0, index=2.0, decay=7, idx_decay=9) * 0.09
            put(b, bar * 4 * beat + k * beat / 2, 1.0, 0.5 if k % 2 else -0.5)
    # risers into each 8-bar section
    for bar in range(6, bars, 8):
        d = 2 * 4 * beat
        m = int(d * SR)
        tt = np.arange(m) / SR
        rs = sweep_lp(rng.standard_normal(m), 200, 9000, block=256) * (tt / d) ** 2.5 * 0.35
        put(rs, bar * 4 * beat, 1.0)
        put(drum_kick(1.2) * 0.9, (bar + 2) * 4 * beat, 1.0)

    mix = hp(mix, 30)
    mix = reverb(mix, wet=0.18, dur=2.5, decay=2.5, bright=7000, tail=False)
    body_n = int(length_s * SR)
    body = mix[:body_n].copy()
    tail_part = mix[body_n:]
    body[:len(tail_part)] += tail_part
    return softclip(body * 1.15, 1.3)


def epiano(freq, dur, vel=1.0):
    t = t_axis(dur)
    mod = np.sin(2 * np.pi * freq * 1.0 * t) * 1.6 * np.exp(-t * 3.0) * vel
    car = np.sin(2 * np.pi * freq * t + mod) + 0.25 * np.sin(2 * np.pi * freq * 2 * t) * np.exp(-t * 4)
    trem = 1 + 0.12 * np.sin(2 * np.pi * 4.5 * t)
    return car * env_exp(dur, 1.4, 0.004) * trem


def music_radio_lofi():
    """'Lane FM': 82 BPM dusty lofi groove - Rhodes chords, swung hats, round sub, vinyl hiss."""
    bpm = 82.0
    beat = 60.0 / bpm
    bars = 32
    length_s = bars * 4 * beat
    n = int((length_s + 4.0) * SR)
    mix = np.zeros((n, 2))
    r = np.random.default_rng(21)
    prog = [[50, 57, 60, 64, 65], [55, 59, 62, 65, 69], [48, 55, 59, 62, 64], [45, 52, 55, 60, 64]]

    def put(sig, ts, g, p=0.0):
        o = int(ts * SR)
        st = pan(sig * g, p) if sig.ndim == 1 else sig * g
        m = min(len(st), n - o)
        if m > 0:
            mix[o:o + m] += st[:m]

    kick = lp(drum_kick(0.5), 2500)
    snare = lp(drum_snare(0.35), 5000)
    hat = lp(drum_hat(0.08), 9000)
    sw = beat * 0.16
    for bar in range(bars):
        t0 = bar * 4 * beat
        ch = prog[(bar // 2) % len(prog)]
        for pos in (0.0, 1.75, 2.5):
            put(kick, t0 + pos * beat, 0.8)
        for pos in (1.0, 3.0):
            put(snare, t0 + pos * beat + 0.02, 0.38, 0.05)
        for k in range(8):
            put(hat, t0 + k * beat / 2 + (sw if k % 2 else 0), 0.14 if k % 2 else 0.2, 0.3)
        # rhodes: stabbed chord on 1 and the "and" of 2, every bar a little different
        for pos in ((0.0, 2.2), (1.5, 1.2) if bar % 2 else (2.5, 1.4)):
            for vi, nt in enumerate(ch[1:]):
                put(epiano(note_hz(nt), pos[1] * beat + 1.0, 0.8), t0 + pos[0] * beat + vi * 0.012, 0.09, -0.4 + vi * 0.25)
        # sub
        m = int(4 * beat * SR)
        tt = np.arange(m) / SR
        root = ch[0] - 12
        b = np.sin(2 * np.pi * note_hz(root) * tt) * np.exp(-tt * 0.8) * 0.5
        put(b, t0, 1.0)
        # melody sprinkle
        if bar % 4 in (1, 3):
            for k in range(3):
                nt = int(r.choice([ch[2] + 12, ch[3] + 12, ch[4] + 12, ch[1] + 24]))
                put(fm_bell(note_hz(nt), 1.2, ratio=1.0, index=0.8, decay=3) * 0.12, t0 + (k * 1.25 + 0.5) * beat, 1.0, r.uniform(-0.6, 0.6))
    hiss = hp(rng.standard_normal(n), 3000) * 0.006
    crackle = (rng.random(n) > 0.9993) * rng.standard_normal(n) * 0.25
    mix += np.stack([hiss + crackle, np.roll(hiss + crackle, 300)], 1)
    mix = lp(mix, 7500)
    mix = reverb(mix, wet=0.18, dur=1.8, decay=3.0, bright=5000, tail=False)
    body_n = int(length_s * SR)
    body = mix[:body_n].copy()
    body[:n - body_n] += mix[body_n:]
    return softclip(body * 1.2, 1.2)


def music_radio_synth():
    """'Neon Drift': 100 BPM synthwave cruise - 8th-note bass, gated pads, big snare, lead hook."""
    bpm = 100.0
    beat = 60.0 / bpm
    bars = 32
    length_s = bars * 4 * beat
    n = int((length_s + 5.0) * SR)
    mix = np.zeros((n, 2))
    prog = [(45, [57, 60, 64]), (41, [57, 60, 65]), (48, [55, 60, 64]), (43, [55, 59, 62])]

    def put(sig, ts, g, p=0.0):
        o = int(ts * SR)
        st = pan(sig * g, p) if sig.ndim == 1 else sig * g
        m = min(len(st), n - o)
        if m > 0:
            mix[o:o + m] += st[:m]

    kick = drum_kick(0.5)
    snare = reverb(stereo(drum_snare(0.6)), wet=0.45, dur=1.5, decay=2.5)
    hat = drum_hat(0.06)
    hook = [12, 7, 9, 7, 4, 7, 2, 0]
    for bar in range(bars):
        t0 = bar * 4 * beat
        root, notes = prog[(bar // 2) % len(prog)]
        for b in range(4):
            put(kick, t0 + b * beat, 0.75)
            put(hat, t0 + b * beat + beat / 2, 0.15, 0.3)
        for b in (1, 3):
            put(snare, t0 + b * beat, 0.4)
        # 8th bass
        for k in range(8):
            m = int(beat / 2 * 0.9 * SR)
            tt = np.arange(m) / SR
            f = note_hz(root - 12 + (12 if k % 2 else 0))
            v = mod_lp(saw(2 * np.pi * f * tt) * np.exp(-tt * 6), 300 + 1400 * np.exp(-tt * 18), block=64)
            put(v, t0 + k * beat / 2, 0.32)
        # gated pad (16ths)
        m = int(4 * beat * SR)
        tt = np.arange(m) / SR
        pad = sum(supersaw(note_hz(x), m, voices=5, detune=0.01, seed=x) for x in notes) / 3
        gate = 0.35 + 0.65 * ((tt % (beat / 4)) < beat / 6)
        put(lp(pad * gate, 2400), t0, 0.12, -0.2)
        put(lp(np.roll(pad * gate, 200), 2400), t0, 0.12, 0.2)
        # lead hook in the second half
        if bar >= 16:
            for k, iv in enumerate(hook):
                if (bar + k) % 3 == 2:
                    continue
                d = beat * 0.45
                mm = int(d * SR)
                tl = np.arange(mm) / SR
                f = note_hz(notes[0] + iv)
                lead = (saw(2 * np.pi * f * tl) + saw(2 * np.pi * f * 1.006 * tl)) * 0.5 * adsr(mm, 0.01, 0.08, 0.6, 0.1)
                put(lp(lead, 3200), t0 + k * beat / 2, 0.08, 0.15)
    mix = delay_pingpong(mix, beat * 0.75, fb=0.3, wet=0.15, n_taps=4, damp=3000)[:n]
    mix = reverb(hp(mix, 30), wet=0.15, dur=2.0, decay=2.8, bright=6000, tail=False)
    body_n = int(length_s * SR)
    body = mix[:body_n].copy()
    body[:n - body_n] += mix[body_n:]
    return softclip(body * 1.15, 1.25)


def music_bar():
    """Cantina: 112 BPM swung shuffle on a detuned piano, upright bass and brushes."""
    bpm = 112.0
    beat = 60.0 / bpm
    bars = 24
    length_s = bars * 4 * beat
    n = int((length_s + 3.0) * SR)
    mix = np.zeros((n, 2))
    r = np.random.default_rng(8)
    prog = [(43, [59, 62, 65]), (43, [59, 62, 65]), (48, [58, 64, 67]), (48, [58, 64, 67]),
            (43, [59, 62, 65]), (50, [60, 65, 66]), (48, [58, 64, 67]), (50, [60, 65, 66])]

    def put(sig, ts, g, p=0.0):
        o = int(ts * SR)
        st = pan(sig * g, p) if sig.ndim == 1 else sig * g
        m = min(len(st), n - o)
        if m > 0:
            mix[o:o + m] += st[:m]

    brush = bp(noise(0.25), 2000, 8000) * np.exp(-t_axis(0.25) * 18)
    sw = beat * 0.66
    for bar in range(bars):
        t0 = bar * 4 * beat
        root, notes = prog[bar % len(prog)]
        for b in range(4):
            put(brush, t0 + b * beat, 0.18 if b % 2 else 0.1, 0.3)
            put(brush, t0 + b * beat + sw, 0.08, 0.35)
            # walking bass
            nt = root - 12 + [0, 4, 7, 9][b]
            m = int(beat * 0.95 * SR)
            tt = np.arange(m) / SR
            bs = np.sin(2 * np.pi * note_hz(nt) * tt) * np.exp(-tt * 3.5) * (1 - np.exp(-tt * 300))
            put(bs + 0.2 * np.sin(4 * np.pi * note_hz(nt) * tt) * np.exp(-tt * 6), t0 + b * beat, 0.42, -0.1)
            # piano comp on the off-beats
            if b % 2 == 1 or r.random() < 0.3:
                for vi, x in enumerate(notes):
                    pn = fm_bell(note_hz(x), 0.7, ratio=1.0, index=1.4, decay=5) + fm_bell(note_hz(x) * 1.004, 0.7, ratio=1.0, index=1.0, decay=5) * 0.5
                    put(pn, t0 + b * beat + sw * (0 if b % 2 == 0 else 1) * 0.5 + vi * 0.008, 0.06, 0.25)
        # right-hand lick
        if bar % 2 == 1:
            for k in range(4):
                nt = int(r.choice([notes[0] + 12, notes[1] + 12, notes[2] + 12, root + 24 + 3]))
                put(fm_bell(note_hz(nt), 0.6, ratio=1.0, index=1.8, decay=6) * 0.09, t0 + k * beat * 0.5 + 2 * beat, 1.0, 0.4)
    murmur = lp(bp(rng.standard_normal(n), 250, 1800), 1500) * 0.012
    mix += np.stack([murmur, np.roll(murmur, 4000)], 1)
    mix = reverb(mix, wet=0.2, dur=1.4, decay=3.5, bright=5000, tail=False)
    body_n = int(length_s * SR)
    body = mix[:body_n].copy()
    body[:n - body_n] += mix[body_n:]
    return softclip(body * 1.2, 1.2)


def main():
    what = sys.argv[1] if len(sys.argv) > 1 else "all"
    if what in ("all", "sfx"):
        print("sfx:")
        only = sys.argv[2:] 
        for name, (fn, peak) in SFX.items():
            if only and name not in only:
                continue
            x = fn()
            if not name.endswith("_loop"):
                x = trim(stereo(x))
            write(name, x, peak=peak)
    if what in ("all", "music"):
        print("music:")
        write("music_flight", music_flight(), peak=0.8, q=5)
        write("music_station", music_station(), peak=0.8, q=5)
    if what in ("all", "music", "radio"):
        write("music_radio_lofi", music_radio_lofi(), peak=0.8, q=5)
        write("music_radio_synth", music_radio_synth(), peak=0.8, q=5)
        write("music_bar", music_bar(), peak=0.8, q=5)
    if what in ("all", "music", "combat"):
        write("music_combat", music_combat(), peak=0.85, q=5)


if __name__ == "__main__":
    main()
