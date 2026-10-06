extends "res://tools/lightning_fire_budget.gd"
## Four representative progress points, no reaction or Boss AI; measure current code.
const BUILDS := [
	{"picks": 0, "lightning": [], "fire": []},
	{"picks": 3, "lightning": ["tower_core", "tower_core", "tower_tide"],
		"fire": ["fire_width", "fire_count", "fire_ground"]},
	{"picks": 6, "lightning": ["tower_rate", "tower_rate", "tower_core", "tower_core", "tower_chain", "tower_judgment"],
		"fire": ["fire_width", "fire_width", "fire_width", "fire_count", "fire_ground", "fire_growth"]},
	{"picks": 9, "lightning": ["tower_rate", "tower_rate", "tower_rate", "tower_core", "tower_core", "tower_core", "tower_chain", "tower_tide", "tower_judgment"],
		"fire": ["fire_width", "fire_width", "fire_width", "fire_count", "fire_count", "fire_count", "fire_push", "fire_ground", "fire_growth"]}
]

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.selected_classes = [0, 0]
	game.start_run()
	for build in BUILDS:
		var lightning := measure(build.lightning, "lightning", false, 60.0, true)
		var fire := measure(build.fire, "fire", false, 60.0, true)
		var row := {"picks": build.picks, "lightning": lightning, "fire_no_reaction": fire,
			"ratio": float(lightning.steady_dps) / float(fire.steady_dps)}
		rows.append(row)
		print("PICKS %d: lightning %.2f DPS / fire %.2f DPS = %.3fx" % [build.picks, lightning.steady_dps, fire.steady_dps, row.ratio])
	var file := FileAccess.open("res://artifacts/lightning_ratio_actual.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(rows, "\t"))
	game.free()
	quit()
