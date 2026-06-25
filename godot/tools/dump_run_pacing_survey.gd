extends SceneTree

const RouteGenerator = preload("res://scripts/generation/route/route_generator.gd")
const RouteNode = preload("res://scripts/run/route_node.gd")
const RouteState = preload("res://scripts/run/route_state.gd")

func _init() -> void:
	var seeds: Array = [0, 1, 2, 3, 5, 7, 11, 13, 17, 42, 99, 100, 256, 314, 777, 1000, 2026, 9999]
	var count_dist: Dictionary = {}
	var type_totals: Dictionary = {}
	var boss_depths: Dictionary = {}
	for s in seeds:
		var gen = RouteGenerator.generate(s)
		var route: RouteState = RouteGenerator.route_from_result(gen)
		var non_boss := 0
		var bdepth := -1
		for node: RouteNode in route.nodes():
			type_totals[String(node.type)] = int(type_totals.get(String(node.type), 0)) + 1
			if node.type == RouteNode.TYPE_BOSS:
				bdepth = node.depth
			else:
				non_boss += 1
		count_dist[non_boss] = int(count_dist.get(non_boss, 0)) + 1
		boss_depths[bdepth] = int(boss_depths.get(bdepth, 0)) + 1
	print("SEEDS=", seeds.size())
	print("NON_BOSS_COUNT_DIST=", count_dist)
	print("BOSS_DEPTH_DIST=", boss_depths)
	print("TYPE_TOTALS=", type_totals)
	quit()
