class_name WarDiplomacyAi
extends RefCounted

## 每年一次的國家外交 AI:Phase 1 骰「今年想不想開戰」,骰中才進 Phase 2 加權抽選
## 對象。見 war_world_time_events.gd yearly_tick() 呼叫 run_yearly_tick()。

const BASE_WANT_CHANCE := 0.02
const TENSION_SLOPE := 0.006
const MAX_WANT_CHANCE := 0.65   # 封頂,WarTension 再高也不會 100% 必然宣戰


static func run_yearly_tick() -> void:
	for nation_id in GameEnums.BloodlineNation.values():
		if NationRelationStore.is_at_war(nation_id):
			continue
		if not _roll_wants_war(nation_id):
			continue
		var target := _pick_target(nation_id)
		if target != -1:
			NationRelationStore.declare_war(nation_id, target)


static func _roll_wants_war(nation_id: int) -> bool:
	var max_tension := _highest_tension_against_others(nation_id)
	var chance := clampf(BASE_WANT_CHANCE + max_tension * TENSION_SLOPE, 0.0, MAX_WANT_CHANCE)
	return Util.get_random_float(0.0, 1.0) <= chance


static func _highest_tension_against_others(nation_id: int) -> float:
	var highest := 0.0
	for other_id in GameEnums.BloodlineNation.values():
		if other_id == nation_id:
			continue
		highest = maxf(highest, NationRelationStore.get_war_tension(nation_id, other_id))
	return highest


## 候選 = 排除自己/已在打仗的對象/低於門檻的國家,用 WarTension 當權重加權隨機——
## 不要永遠選 tension 最高的那個。Util.get_random_chance_item_detailed() 的
## WeightedRollResult.key 型別是 String,候選 dictionary 的 key 要先轉成字串,抽中後
## 再轉回 int,不能直接塞 int key 進去。
static func _pick_target(nation_id: int) -> int:
	var chance_map: Dictionary = {}
	for other_id in GameEnums.BloodlineNation.values():
		if other_id == nation_id:
			continue
		if NationRelationStore.is_at_war(other_id):
			continue
		var tension := NationRelationStore.get_war_tension(nation_id, other_id)
		if tension < WarTensionRule.DECLARE_CANDIDATE_TENSION_THRESHOLD:
			continue
		chance_map[str(other_id)] = tension
	if chance_map.is_empty():
		return -1
	return int(Util.get_random_chance_item_detailed(chance_map).key)
