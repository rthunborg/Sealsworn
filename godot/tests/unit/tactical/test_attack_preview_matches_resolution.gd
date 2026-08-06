extends "res://tests/unit/test_case.gd"

# Story 15.2 (F4 / AC2) — THE preview-equals-resolved guard-rail. The attack PREVIEW is a read model that must show the
# SAME number the committed attack resolves. Story 12.2 gave AttackCommand a deterministic tome +1 for staff/wand, but the
# preview was never taught the loadout support, so the shown `expected_damage` was weapon-base while `final_damage` was
# base+bonus. This test locks `TacticalAttackPreview.from_query(...).metadata.expected_damage == AttackCommand.final_damage`
# for EVERY MVP class starting kit so a future bonus source cannot silently desynchronize them again. It also proves the
# preview is a PURE read (zero board mutation, zero RNG) and that a no-bonus support never over-counts.

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const AttackCommand = preload("res://scripts/core/commands/attack_command.gd")
const BoardFixtureFactory = preload("res://tests/fixtures/tactical/board_fixture_factory.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")
const SupportDefinition = preload("res://scripts/content/definitions/support_definition.gd")
const SupportRepository = preload("res://scripts/content/repositories/support_repository.gd")
const TacticalActionContext = preload("res://scripts/tactical/tactical_action_context.gd")
const TacticalAttackPreview = preload("res://scripts/ui/view_models/tactical_attack_preview.gd")
const TacticalTurnState = preload("res://scripts/tactical/turns/tactical_turn_state.gd")
const WeaponDefinition = preload("res://scripts/content/definitions/weapon_definition.gd")
const WeaponRepository = preload("res://scripts/content/repositories/weapon_repository.gd")

func run() -> Dictionary:
	_preview_equals_resolved_for_each_starting_kit()
	_preview_is_a_pure_read_with_no_mutation_or_rng()
	return result()


# AC2 — for each class starting kit, the previewed number equals the resolved final damage, and both equal the expected
# hand-computed value. Pyromancer staff+tome is checked at BOTH a ranged and an adjacent cell (the adjacency x tome
# interaction: base 4 ranged / floor(4*0.5)=2 adjacent, +1 tome -> 5 / 3). Warrior sword+shield proves the shield adds 0
# as attacker support (no over-count). Ranger bow+none proves the no-support path is byte-identical (3 ranged / 2 adjacent).
func _preview_equals_resolved_for_each_starting_kit() -> void:
	for case_data: Dictionary in _starting_kit_cases():
		var case_id: String = String(case_data.get("id", ""))
		var weapon: WeaponDefinition = _weapon(case_data.get("weapon"))
		var support: SupportDefinition = _support(case_data.get("support"))
		var target_cell: Vector2i = case_data.get("target")
		var expected: int = int(case_data.get("expected"))

		var preview_board: BoardState = _fixture(String(case_data.get("fixture", "")))
		var previewed: int = _previewed_expected_damage(preview_board, target_cell, weapon, support)

		# Resolve on a FRESH board so the previewed read cannot influence the committed mutation.
		var resolve_board: BoardState = _fixture(String(case_data.get("fixture", "")))
		var streams: RngStreamSet = RngStreamSet.new(4242)
		var result_value: ActionResult = AttackCommand.new(&"hero", target_cell, weapon, support, null).execute(_context(resolve_board, streams))
		assert_true(result_value.succeeded, "Kit %s should resolve a legal attack." % case_id)
		var resolved: int = int(result_value.metadata.get("final_damage", -1))

		assert_equal(previewed, expected, "Kit %s previewed damage should be %d." % [case_id, expected])
		assert_equal(resolved, expected, "Kit %s resolved final_damage should be %d." % [case_id, expected])
		assert_equal(previewed, resolved, "Kit %s: previewed expected_damage must equal resolved final_damage." % case_id)


# AC2 — the preview draws ZERO RNG and mutates NOTHING (arming leaves the run byte-identical), and a null / no-bonus
# support yields expected_damage == expected_base_damage while the tome yields expected_base_damage + 1.
func _preview_is_a_pure_read_with_no_mutation_or_rng() -> void:
	for case_data: Dictionary in _starting_kit_cases():
		var case_id: String = String(case_data.get("id", ""))
		var weapon: WeaponDefinition = _weapon(case_data.get("weapon"))
		var support: SupportDefinition = _support(case_data.get("support"))
		var board: BoardState = _fixture(String(case_data.get("fixture", "")))
		var streams: RngStreamSet = RngStreamSet.new(4242)
		var board_before: Dictionary = board.to_snapshot()
		var rng_before: Dictionary = streams.to_snapshot()

		var preview: Dictionary = TacticalAttackPreview.from_query(board, &"hero", case_data.get("target"), weapon, support).to_dictionary()
		var metadata: Dictionary = preview.get("metadata", {})

		assert_equal(board.to_snapshot(), board_before, "Kit %s preview must not mutate the board." % case_id)
		assert_equal(streams.to_snapshot(), rng_before, "Kit %s preview must not advance any RNG stream." % case_id)

		var base: int = int(metadata.get("expected_base_damage", -999))
		var total: int = int(metadata.get("expected_damage", -999))
		if String(case_data.get("support")) == "tome":
			assert_equal(total, base + 1, "Kit %s: the tome folds exactly +1 over the weapon base." % case_id)
		else:
			assert_equal(total, base, "Kit %s: a no-bonus support keeps expected_damage equal to the weapon base." % case_id)


func _starting_kit_cases() -> Array[Dictionary]:
	return [
		# Pyromancer: staff (base 4, HALF x0.5 adjacent -> 2) + tome (+1 for staff/wand).
		{"id": "pyromancer_staff_ranged", "fixture": "attack_preview_open_lane", "weapon": &"staff", "support": &"tome", "target": Vector2i(3, 1), "expected": 5},
		{"id": "pyromancer_staff_adjacent", "fixture": "attack_preview_adjacent_enemy", "weapon": &"staff", "support": &"tome", "target": Vector2i(2, 1), "expected": 3},
		# Warrior: sword (base 4, no adjacency) + shield (bonus_damage 0 -> adds nothing as attacker support).
		{"id": "warrior_sword_shield", "fixture": "attack_preview_adjacent_enemy", "weapon": &"sword", "support": &"shield", "target": Vector2i(2, 1), "expected": 4},
		# Ranger: bow (base 3, RANGED_70 x0.7 adjacent -> 2) + none (the byte-identical no-support path).
		{"id": "ranger_bow_ranged", "fixture": "attack_preview_open_lane", "weapon": &"bow", "support": &"none", "target": Vector2i(3, 1), "expected": 3},
		{"id": "ranger_bow_adjacent", "fixture": "attack_preview_adjacent_enemy", "weapon": &"bow", "support": &"none", "target": Vector2i(2, 1), "expected": 2}
	]


func _previewed_expected_damage(board: BoardState, target_cell: Vector2i, weapon: WeaponDefinition, support: SupportDefinition) -> int:
	var preview: Dictionary = TacticalAttackPreview.from_query(board, &"hero", target_cell, weapon, support).to_dictionary()
	var metadata: Dictionary = preview.get("metadata", {})
	return int(metadata.get("expected_damage", -999))


func _fixture(fixture_name: String) -> BoardState:
	match fixture_name:
		"attack_preview_open_lane":
			return BoardFixtureFactory.attack_preview_open_lane()
		"attack_preview_adjacent_enemy":
			return BoardFixtureFactory.attack_preview_adjacent_enemy()
		_:
			assert_true(false, "Unknown fixture: %s" % fixture_name)
			return BoardFixtureFactory.attack_preview_adjacent_enemy()


func _weapon(weapon_id: StringName) -> WeaponDefinition:
	return WeaponRepository.create_baseline_repository().get_weapon(weapon_id)


func _support(support_id: StringName) -> SupportDefinition:
	return SupportRepository.create_baseline_repository().get_support(support_id)


func _context(board: BoardState, streams: RngStreamSet) -> TacticalActionContext:
	var turn_state: TacticalTurnState = TacticalTurnState.new(1, TacticalTurnState.Phase.PLAYER_PLANNING, &"hero")
	return TacticalActionContext.new(board, turn_state, streams)
