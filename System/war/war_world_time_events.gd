class_name WarWorldTimeEvents
extends RefCounted

## WorldTimeEventLibrary.register_all() 委派的戰爭系統月/年邏輯彙整層——集中在這裡
## 而不是塞進 world_time_event_library.gd 本身,比照該檔案自己拆分職責的精神。全部是
## static 函式,不會被實例化,lambda 包一層純粹是登記慣例統一,不受 RefCounted 生命
## 週期陷阱影響。


static func monthly_tick() -> void:
	_advance_active_battles()
	_spawn_ready_battles()
	_decay_ended_war_exhaustion()
	_apply_random_tension_drift()
	_run_truce_checks()


static func yearly_tick() -> void:
	WarDiplomacyAi.run_yearly_tick()
	_decay_peacetime_tension()


static func _advance_active_battles() -> void:
	for war: War in NationRelationStore.wars.values():
		if war.status != GameEnums.WarStatus.ACTIVE:
			continue
		# duplicate() 是必要的——settle_battle() 會在迴圈中把結算掉的戰場從
		# war.active_battles 移除,直接迭代原陣列會邊跑邊改動、漏掉或跳過其他戰場。
		for battle: WarBattle in war.active_battles.duplicate():
			var result := WarBattleSimulation.advance_month(battle)
			if result != null:
				NationRelationStore.settle_battle(war, battle, result)


## 只要還沒到 WarBattleSpawner.MAX_CONCURRENT_BATTLES 上限,到了排定的
## next_battle_spawn_day 就補一個新戰場——跟戰場結算與否脫鉤,呼應「戰爭期間可能同時
## 多個戰場」,不是等前一場結算完才生下一場。
static func _spawn_ready_battles() -> void:
	var current_day := WorldTimeStore.controller.world_time.get_day_count()
	for war: War in NationRelationStore.wars.values():
		if war.status != GameEnums.WarStatus.ACTIVE:
			continue
		if war.active_battles.size() >= WarBattleSpawner.MAX_CONCURRENT_BATTLES:
			continue
		if war.next_battle_spawn_day != -1 and current_day >= war.next_battle_spawn_day:
			WarBattleSpawner.spawn_battle(war)


static func _decay_ended_war_exhaustion() -> void:
	for war: War in NationRelationStore.wars.values():
		if war.status != GameEnums.WarStatus.ENDED:
			continue
		war.war_exhaustion_a = WarExhaustionRule.decay(war.war_exhaustion_a)
		war.war_exhaustion_b = WarExhaustionRule.decay(war.war_exhaustion_b)


## 停戰判定改成月度(原本是年度)——戰場結算前最長只有 1~3 個月,年度判定跟不上這個
## 時間尺度,會讓戰爭在系統上早就沒有新戰場了卻遲遲不進入停戰狀態。
static func _run_truce_checks() -> void:
	for war: War in NationRelationStore.wars.values():
		if war.status != GameEnums.WarStatus.ACTIVE:
			continue
		var avg := (war.war_exhaustion_a + war.war_exhaustion_b) / 2.0
		if Util.get_random_float(0.0, 1.0) <= WarTruceRule.truce_probability(avg):
			NationRelationStore.resolve_truce(war)


## 每個月對每一組沒有進行中戰爭的國家對套用一次 ±MONTHLY_RANDOM_DRIFT_RANGE 的隨機
## 波動(邊境衝突/資源爭奪等瑣碎摩擦的簡化版)——沒有這個,WarTension 只會靠
## PEACETIME_YEARLY_DECAY 單調下降,永遠不會自然爬到 DECLARE_CANDIDATE_TENSION_THRESHOLD
## 觸發宣戰,WarDiplomacyAi 就形同虛設。跟 _decay_peacetime_tension() 同樣只處理沒有
## 進行中戰爭的國家對。
static func _apply_random_tension_drift() -> void:
	var nations := GameEnums.BloodlineNation.values()
	for i in nations.size():
		for j in range(i + 1, nations.size()):
			var nation_a: int = nations[i]
			var nation_b: int = nations[j]
			if NationRelationStore.get_active_war_between(nation_a, nation_b) != null:
				continue
			var drift := Util.get_random_float(-WarTensionRule.MONTHLY_RANDOM_DRIFT_RANGE, WarTensionRule.MONTHLY_RANDOM_DRIFT_RANGE)
			NationRelationStore.modify_war_tension(nation_a, nation_b, drift)


## 只有雙方都沒有進行中戰爭的國家對才會自然衰減 WarTension——正在打仗的兩國,張力靠
## 戰場結果推動,不會平白下降。
static func _decay_peacetime_tension() -> void:
	var nations := GameEnums.BloodlineNation.values()
	for i in nations.size():
		for j in range(i + 1, nations.size()):
			var nation_a: int = nations[i]
			var nation_b: int = nations[j]
			if NationRelationStore.get_active_war_between(nation_a, nation_b) != null:
				continue
			NationRelationStore.modify_war_tension(nation_a, nation_b, -WarTensionRule.PEACETIME_YEARLY_DECAY)
