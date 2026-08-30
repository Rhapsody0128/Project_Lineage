class_name RoamingEnemyEvent
extends LocationEvent

## 大地圖走近遊蕩敵人(RoamingEnemy)觸發的「先跳對話,再選擇要不要開戰」流程,比照
## System/event/town/town_gate_event.gd 的 TownGateEvent,但精簡掉城門守衛「已經
## 站在門口」的判斷與 NavigationStore.push_return_scene_path()——這裡本來就是在
## Scenes/Map/map.tscn 上直接觸發,對話/戰鬥打完也是回到同一個 map.tscn,不需要額外記錄
## 「上一頁」。呼叫端(map.gd 偵測到玩家走近敵人時)只呼叫一次
## RoamingEnemyEvent.trigger(enemy)。敵人要不要從地圖上移除,只看戰鬥有沒有真的打贏:
## SELF_WIN 才呼叫 RoamingEnemySpawner.remove_enemy() 消耗掉;選「離開」、或開打了但戰敗/
## 平手,敵人都不會消失,一律呼叫 decline_encounter() 留著敵人只是暫時擋掉重複觸發
## (見 RoamingEnemySpawner 的 DECLINED_CLEAR_RADIUS 註解)——盜賊搶完戰利品後應該還在
## 原地,不是打完就憑空消失。

const RETURN_SCENE_PATH := "res://Scenes/Map/map.tscn"

var _enemy: RoamingEnemy


func _init(p_enemy: RoamingEnemy) -> void:
	_enemy = p_enemy


static func trigger(enemy: RoamingEnemy) -> void:
	var event := RoamingEnemyEvent.new(enemy)
	event._start()


## 遭遇當下重新依敵人「目前座標」所在地圖色塊指派所屬國家,覆寫生成當下的舊值——敵人
## 生成後會原地遊蕩(見 System/map/roaming_enemy.gd 的 WANDER_RADIUS),可能已經漂出
## 生成當下的色塊範圍。戰鬥獎勵/好感度(BattleReward.grant_victory_favor)、討伐委託完成
## 判定(QuestStore.notify_bandit_defeated)都要看「在哪裡被擊退」,不是「出生/牠自己
## 血統是哪國」,所以在真正觸發遭遇的這一刻覆寫 party.nation_type,下游全部跟著更新;
## 查不到(理論上不會發生,見 MapTerrainMask 的可行走判定)時維持生成當下指派的舊值,
## 不覆寫成 -1。
func _start() -> void:
	var current_nation := MapTerrainMask.nation_at(_enemy.position)
	if current_nation != -1:
		_enemy.party.nation_type = current_nation

	var self_party := PartyStore.party
	var dialogue := _build_challenge(self_party, func():
		AskBattle.ask(
			self_party, _enemy.party,
			"res://Scenes/Battle/battle.tscn", RETURN_SCENE_PATH,
			"", _on_battle_result
		)
	)
	goto_dialogue(dialogue, RETURN_SCENE_PATH)


## 只有真的打贏才把敵人從地圖上消耗掉;戰敗或平手都算沒能擊退盜賊,敵人留在原地——
## 跟選「離開」共用同一套 decline_encounter() 暫時擋重觸發機制,避免播完結果對話回到
## map.tscn 時玩家還站在原地,立刻又撞上同一隻敵人重播一次。打贏同時通知 QuestStore
## 檢查這隻敵人的所屬國家(見 _background_path() 同一份 party.nation_type)有沒有進行中的
## 「討伐周邊強盜」任務,有的話直接完成、補發任務獎勵(見 QuestStore.notify_bandit_defeated())
## ——一般擊退盜賊的金錢/好感度獎勵已經由 Battle 場景照常發放,這裡不重複。
func _on_battle_result(result: GameEnums.BattleResultType) -> void:
	if result == GameEnums.BattleResultType.SELF_WIN:
		RoamingEnemyStore.spawner.remove_enemy(_enemy)
		if _enemy.party.nation_type != -1:
			QuestStore.notify_bandit_defeated(_enemy.party.nation_type)
	else:
		RoamingEnemyStore.spawner.decline_encounter(_enemy)
	goto_dialogue(_build_result(result), RETURN_SCENE_PATH)


## self_party 可能是 null(玩家還沒去 PartyEdit 按過「完成編輯」)——這種情況不生一支假的
## 隨機小隊頂替,直接不給「戰鬥」選項,只能「離開」,比照 TownGateEvent._build_challenge。
## 開口說話的一律是 LeaderStore.get_leader()(整團領導人),不是 self_party.leader
## (戰場隊長)——即使玩家還沒編隊,整團領導人一樣存在(預設主角),見
## Scripts/Autoload/leader_store.gd 開頭註解。
func _build_challenge(self_party: Party, on_challenge_accepted: Callable) -> Dialogue:
	var has_party := self_party != null
	var player := LeaderStore.get_leader()
	var bandit := _enemy.party.leader

	var player_speaker := DialogueSpeaker.new(player.id, player.title_full_name, player.face_path, GameEnums.DialogueSide.LEFT)
	var bandit_speaker := DialogueSpeaker.new(bandit.id, bandit.title_full_name, bandit.face_path, GameEnums.DialogueSide.RIGHT)

	# 選「離開」不消耗敵人,只是暫時擋掉重複觸發,讓玩家可以晚點回頭再打——跟打輸/
	# 平手同一套機制,見 _on_battle_result()。敵人只有在真的打贏時才會被 remove_enemy()。
	var on_declined := func(): RoamingEnemyStore.spawner.decline_encounter(_enemy)

	var lines: Array[DialogueLine] = []

	var encounter_text := "一群%s擋住了去路！" % _bandit_label()

	if has_party:
		var stakes_text := _build_stakes_text()
		var choices: Array[DialogueChoice] = [
			DialogueChoice.new("戰鬥", "", on_challenge_accepted),
			DialogueChoice.new("離開", RETURN_SCENE_PATH, on_declined),
		]
		lines = [
			DialogueLine.new(bandit_speaker.id, encounter_text),
			DialogueLine.new(player_speaker.id, stakes_text, choices),
		]
	else:
		var choices: Array[DialogueChoice] = [
			DialogueChoice.new("離開", RETURN_SCENE_PATH, on_declined),
		]
		lines = [
			DialogueLine.new(bandit_speaker.id, encounter_text),
			DialogueLine.new(player_speaker.id, "（我還沒整頓好隊伍,先撤退吧。）", choices),
		]

	return Dialogue.new([bandit_speaker, player_speaker], lines, _background_path())


## 依 party.nation_type(見 _start() 已在遭遇當下覆寫成「目前座標」所在國家)換算成地形
## 對應的強盜稱呼(GameEnums.terrain_bandit_label()),-1(理論上不會發生)時 fallback 回
## 中性的「強盜」。
func _bandit_label() -> String:
	var nation_type := _enemy.party.nation_type
	if nation_type == -1:
		return "強盜"
	return GameEnums.bandit_label_for_nation(nation_type)


## 遭遇對話背景圖優先看敵人目前座標在地圖色塊 mask(見 System/map/map_terrain_mask.gd)
## 上屬於哪個地形——不管敵人 party 所屬國家是哪國(例如遊蕩到冰原範圍裡的其他國家盜賊,
## 畫面也要顯示冰原,不是牠原本國家的地形)。查不到(理論上不會發生,敵人只會生成在
## mask 判定可行走的地方)才 fallback 回舊版「依 party.nation_type 換算地形」
## (Images/Dialogue/Map/Terrain/<TERRAIN>.png,見 GameEnums.bloodline_nation_terrain()),
## nation_type == -1(理論上不會發生,見 _build_stakes_text() 同樣的防呆)時退回 PLAINS
## 當中性預設值。
func _background_path() -> String:
	var mask_nation := MapTerrainMask.nation_at(_enemy.position)
	if mask_nation != -1:
		return GameEnums.terrain_background_path(GameEnums.bloodline_nation_terrain(mask_nation))
	var nation_type := _enemy.party.nation_type
	var terrain_type := GameEnums.bloodline_nation_terrain(nation_type) if nation_type != -1 else GameEnums.TerrainType.PLAINS
	return GameEnums.terrain_background_path(terrain_type)


## 開戰前先告知玩家這場遭遇的評級/金錢與好感度利害關係(見 System/battle/battle_reward.gd
## 的三張 RankType 查表)。_enemy.party.nation_type 一律由 _start() 依遭遇當下座標
## (MapTerrainMask.nation_at())指派,理論上不會是 -1,但仍防呆處理。
func _build_stakes_text() -> String:
	var rank_label := GameEnums.rank_label(_enemy.rank)
	var reward := BattleReward.money_reward_for_rank(_enemy.rank)
	var penalty := BattleReward.money_penalty_for_rank(_enemy.rank)
	var nation_type := _enemy.party.nation_type
	if nation_type == -1:
		return "（看起來是 %s 級的對手,打贏能拿到 %d 金錢,打輸會被搶走 %d 金錢。）" % [rank_label, reward, penalty]
	var nation_label := GameEnums.bloodline_nation_label(nation_type)
	var favor := BattleReward.favor_for_rank(_enemy.rank)
	return "（看起來是 %s 國附近、%s 級的對手,打贏能拿到 %d 金錢與 %s 好感度 +%d,打輸會被搶走 %d 金錢。）" % [nation_label, rank_label, reward, nation_label, favor, penalty]


## 單句台詞沒有選項,播完由 goto_dialogue() 傳的 RETURN_SCENE_PATH 自動接手轉場。
## DRAW(平手)沒有另外的台詞,一律當作沒能擊退盜賊,跟戰敗共用同一句,比照 TownGateEvent。
func _build_result(result: GameEnums.BattleResultType) -> Dialogue:
	var bandit_speaker := DialogueSpeaker.new(_enemy.party.leader.id, _enemy.party.leader.title_full_name, _enemy.party.leader.face_path, GameEnums.DialogueSide.RIGHT)
	var narrator := DialogueSpeaker.new("narrator", "", "", GameEnums.DialogueSide.NARRATOR)
	var lines: Array[DialogueLine] = []
	if result == GameEnums.BattleResultType.SELF_WIN:
		var reward := BattleReward.money_reward_for_rank(_enemy.rank)
		var nation_type := _enemy.party.nation_type
		var loot_text := "（搜刮到 %d 金錢。）" % reward
		if nation_type != -1:
			var favor := BattleReward.favor_for_rank(_enemy.rank)
			loot_text = "（搜刮到 %d 金錢,%s 對你的好感度 +%d。）" % [reward, GameEnums.bloodline_nation_label(nation_type), favor]
		lines = [
			DialogueLine.new(bandit_speaker.id, "可惡！你們贏了！我投降！"),
			DialogueLine.new(narrator.id, loot_text),
		]
	elif result == GameEnums.BattleResultType.ENEMY_WIN:
		var penalty := BattleReward.money_penalty_for_rank(_enemy.rank)
		lines = [
			DialogueLine.new(bandit_speaker.id, "哈哈！乖乖把值錢的東西留下吧！"),
			DialogueLine.new(narrator.id, "（被搶走了 %d 金錢……）" % penalty),
		]
	else: # DRAW
		lines = [
			DialogueLine.new(bandit_speaker.id, "這次不分勝負！暫時性撤退!"),
		]

	return Dialogue.new([bandit_speaker, narrator], lines, _background_path())
