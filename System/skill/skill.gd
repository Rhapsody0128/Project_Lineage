class_name Skill
extends RefCounted

var id: String
var name: String
var description: String
var skill_rank: int
var skill_range: int
var scope: int
var effect_stat: int
var skill_type: int
var bind_weapon: int
var is_leader_skill: bool
var base_chance: float
var skill_ratio: float
var action: Callable

func _init(
	p_name: String,
	p_description: String,
	p_skill_rank: int,
	p_range: int,
	p_scope: int,
	p_effect_stat: int,
	p_skill_type: int,
	p_bind_weapon: int,
	p_is_leader_skill: bool,
	p_base_chance: float,
	p_skill_ratio: float,
	p_action: Callable
) -> void:
	id = Util.generate_uuid()
	name = p_name
	description = p_description
	skill_rank = p_skill_rank
	skill_range = p_range
	scope = p_scope
	effect_stat = p_effect_stat
	skill_type = p_skill_type
	bind_weapon = p_bind_weapon
	is_leader_skill = p_is_leader_skill
	base_chance = p_base_chance
	skill_ratio = p_skill_ratio
	action = p_action

func effect(self_party, target_party) -> void:
	if action.is_valid():
		action.call(self_party, target_party, self)
