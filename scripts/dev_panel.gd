class_name DevPanel
extends Modal
## Testing cheats (Settings → Dev mode): credits, parts, blueprints, ammo,
## repairs, any ship, any gear. Everything goes through GameState so it is
## saved like normal progress.

var _status: Label
var _scroll: KineticScroll


func _ready() -> void:
	_frame("DEV MENU", 900)
	_status = Modal.label("", 16, UiKit.GOLD, UiKit.display(700, 1))
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(_status)
	_scroll = KineticScroll.new()
	_scroll.custom_minimum_size = Vector2(852, 470)
	body.add_child(_scroll)
	var c := _scroll.content

	_section(c, "Credits")
	_grid(c, [
		["+10,000 cr", func(): _credits(10000)],
		["+100,000 cr", func(): _credits(100000)],
		["+1,000,000 cr", func(): _credits(1000000)],
	])
	_section(c, "Ship")
	_grid(c, [
		["Repair + refill", _refill],
		["+20 missiles (all)", _ammo],
		["Max jump charges", _jumps],
		["+10 every part", _parts],
		["All blueprints", _blueprints],
		["Fill cargo hold", _cargo],
	])
	_section(c, "Get a ship (free, keeps gear that fits)")
	var ships := []
	for id in Items.SHIPS:
		ships.append([Items.SHIPS[id]["name"], _ship.bind(id)])
	_grid(c, ships)
	_section(c, "Add gear to the locker")
	var gear := []
	for id in Items.GEAR:
		var g: Dictionary = Items.GEAR[id]
		gear.append([("★ " if g.get("unique", false) else "") + g["name"], _gear.bind(id)])
	_grid(c, gear)

	var row := HBoxContainer.new()
	body.add_child(row)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sp)
	var back := UiKit.button("BACK", Vector2(200, 58), 20)
	back.pressed.connect(close)
	row.add_child(back)


func _refresh() -> void:
	_status.text = "%d cr   ·   %s   ·   locker %d" % [GameState.credits, Items.SHIPS[GameState.ship]["name"], GameState.storage.size()]


func _section(parent: Control, text: String) -> void:
	parent.add_child(Modal.label(text.to_upper(), 15, UiKit.ACCENT, UiKit.display(700, 2)))


func _grid(parent: Control, items: Array) -> void:
	var g := GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 10)
	for it in items:
		var b := UiKit.button(it[0], Vector2(270, 50), 14)
		b.pressed.connect(it[1])
		g.add_child(b)
	parent.add_child(g)


func _done(msg: String) -> void:
	world.sfx.ui("buy")
	GameState.message.emit("DEV: " + msg, UiKit.GOLD)
	_refresh()


func _credits(n: int) -> void:
	GameState.credits += n
	_done("+%d cr" % n)


func _refill() -> void:
	GameState.hull = GameState.max_hull()
	if world.player:
		world.player.shield = GameState.max_shield()
		world.player.boost_energy = 1.0
	GameState.jump_charges = GameState.max_jump_charges()
	_done("Hull, shield, boost and jump charges full")


func _jumps() -> void:
	GameState.jump_charges = GameState.max_jump_charges()
	_done("Jump charges full")


func _ammo() -> void:
	for k in Items.AMMO:
		GameState.ammo[k] = GameState.ammo.get(k, 0) + 20
	_done("+20 of every missile type")


func _parts() -> void:
	var add := {}
	for k in Items.PARTS:
		add[k] = 10
	GameState.add_parts(add)
	_done("+10 of every part")


func _blueprints() -> void:
	for k in Items.BLUEPRINTS:
		GameState.blueprints[k] = true
	_done("Every blueprint unlocked")


func _cargo() -> void:
	var keys := Galaxy.COMMODITIES.keys()
	var i := 0
	while GameState.cargo_used() < GameState.cargo_capacity():
		var k: String = keys[i % keys.size()]
		GameState.cargo[k] = GameState.cargo.get(k, 0) + 1
		i += 1
	_done("Cargo hold filled")


func _ship(id: String) -> void:
	GameState.ship = id
	GameState._normalize_equip()
	GameState.hull = GameState.max_hull()
	GameState.jump_charges = mini(GameState.jump_charges, GameState.max_jump_charges())
	if world.player:
		world.player.refresh_ship()
		world.player.shield = GameState.max_shield()
	_done("Now flying the " + Items.SHIPS[id]["name"])


func _gear(id: String) -> void:
	GameState.storage.append(id)
	_done(Items.GEAR[id]["name"] + " added to the locker")
