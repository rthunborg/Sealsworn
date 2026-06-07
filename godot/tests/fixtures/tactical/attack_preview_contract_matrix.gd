class_name AttackPreviewContractMatrix
extends RefCounted

static func baseline_cases() -> Array[Dictionary]:
	return [
		{
			"id": "sword_adjacent_enemy",
			"fixture": "attack_preview_adjacent_enemy",
			"weapon_id": &"sword",
			"target_cell": Vector2i(2, 1),
			"expected_reason": "valid",
			"expected_base_damage": 4,
			"expected_blocker_ignored": false
		},
		{
			"id": "bow_adjacent_penalty",
			"fixture": "attack_preview_adjacent_enemy",
			"weapon_id": &"bow",
			"target_cell": Vector2i(2, 1),
			"expected_reason": "valid",
			"expected_base_damage": 2,
			"expected_warning_ids": ["adjacent_ranged_penalty"],
			"expected_blocker_ignored": false
		},
		{
			"id": "bow_blocked_line",
			"fixture": "attack_preview_blocked_lane",
			"weapon_id": &"bow",
			"target_cell": Vector2i(4, 1),
			"expected_reason": "blocked_line",
			"expected_base_damage": -1,
			"expected_blocker_ignored": false
		},
		{
			"id": "wand_blocker_override",
			"fixture": "attack_preview_blocked_lane",
			"weapon_id": &"wand",
			"target_cell": Vector2i(4, 1),
			"expected_reason": "valid",
			"expected_base_damage": 2,
			"expected_effect_ids": ["ignore_blockers"],
			"expected_blocker_ignored": true
		},
		{
			"id": "sword_diagonal_rejected",
			"fixture": "attack_preview_diagonal_enemy",
			"weapon_id": &"sword",
			"target_cell": Vector2i(1, 1),
			"expected_reason": "not_aligned",
			"expected_base_damage": -1,
			"expected_blocker_ignored": false
		},
		{
			"id": "sword_out_of_range",
			"fixture": "attack_preview_open_lane",
			"weapon_id": &"sword",
			"target_cell": Vector2i(3, 1),
			"expected_reason": "out_of_range",
			"expected_base_damage": -1,
			"expected_blocker_ignored": false
		},
		{
			"id": "bow_hidden_target",
			"fixture": "attack_preview_hidden_enemy",
			"weapon_id": &"bow",
			"target_cell": Vector2i(2, 1),
			"expected_reason": "not_visible",
			"expected_base_damage": -1,
			"expected_blocker_ignored": false
		},
		{
			"id": "bow_memory_target",
			"fixture": "attack_preview_memory_enemy",
			"weapon_id": &"bow",
			"target_cell": Vector2i(2, 1),
			"expected_reason": "not_visible",
			"expected_base_damage": -1,
			"expected_blocker_ignored": false
		},
		{
			"id": "bow_missing_target",
			"fixture": "attack_preview_empty_target",
			"weapon_id": &"bow",
			"target_cell": Vector2i(2, 1),
			"expected_reason": "missing_target",
			"expected_base_damage": -1,
			"expected_blocker_ignored": false
		},
		{
			"id": "sword_dead_target",
			"fixture": "attack_preview_dead_target",
			"weapon_id": &"sword",
			"target_cell": Vector2i(2, 1),
			"expected_reason": "dead_target",
			"expected_base_damage": -1,
			"expected_blocker_ignored": false
		},
		{
			"id": "sword_friendly_target",
			"fixture": "attack_preview_friendly_target",
			"weapon_id": &"sword",
			"target_cell": Vector2i(2, 1),
			"expected_reason": "friendly_target",
			"expected_base_damage": -1,
			"expected_blocker_ignored": false
		}
	]
