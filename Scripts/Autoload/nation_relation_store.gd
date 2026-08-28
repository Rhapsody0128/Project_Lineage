extends Node

# =========================================================
# 國與國之間的 WarTension/War 紀錄(autoload,見 project.godot)。跟 NationFavorStore
# 同一套慣例:這是 Scenes 層的 session 狀態,不是規則邏輯——實際的機率/數值規則在
# System/war/ 底下的一批純 RefCounted 類別,這裡只負責持有資料、提供讀寫入口、發
# News/存檔。玩家對單一國家的好感度(Player → Nation)仍然是 NationFavorStore,兩者
# 刻意分開,不要混在一起(見 CLAUDE.md「國際戰爭」設計理念)。
# =========================================================

signal changed

const MAX_ACTIVE_WARS_PER_NATION := 1

## "min_id_max_id" 字串 key(min/max 為 GameEnums.BloodlineNation id)→ WarTension 浮點值。
var tension: Dictionary = {}
## war_id -> War
var wars: Dictionary = {}


## 開場先讓豹/鷹兩國直接處於交戰狀態,不用快轉好幾年賭 WarDiplomacyAi 骰不骰得到才能
## 測試——比照 BattleReportStore._seed_demo_reports() 開場塞兩筆 DEMO 戰報的慣例。讀檔
## (load_save_data())會整包覆蓋 wars/tension,這筆種子資料只在開新遊戲時有效。
func _ready() -> void:
	_seed_random_tensions()
	declare_war(GameEnums.BloodlineNation.LEOPARD, GameEnums.BloodlineNation.EAGLE)


## 開場先給每組國家對一個隨機起始 WarTension(見 WarTensionRule.INITIAL_TENSION_MAX),
## 不再全部從 0 開始,戰爭觸發機率才不會低到幾乎不會發生。豹/鷹兩國緊接著會被
## declare_war() 直接判定交戰,它們之間的隨機起始值不影響任何邏輯(交戰中的國家對本來就
## 不會再被 _apply_random_tension_drift()/WarDiplomacyAi._pick_target() 用 tension 觸發
## 新戰爭)。讀檔會整包覆蓋 tension,這筆種子資料只在開新遊戲時有效。
func _seed_random_tensions() -> void:
	var nations := GameEnums.BloodlineNation.values()
	for i in nations.size():
		for j in range(i + 1, nations.size()):
			tension[_pair_key(nations[i], nations[j])] = Util.get_random_float(0.0, WarTensionRule.INITIAL_TENSION_MAX)


static func _pair_key(nation_a: int, nation_b: int) -> String:
	return "%d_%d" % [mini(nation_a, nation_b), maxi(nation_a, nation_b)]


func get_war_tension(nation_a: int, nation_b: int) -> float:
	return tension.get(_pair_key(nation_a, nation_b), 0.0)


## 唯一改動 WarTension 的入口,永遠夾在 0-100——保持 public,未來的玩家外交操作
## (離間/遊說等)直接呼叫這個函式即可,不需要另開一條路。
func modify_war_tension(nation_a: int, nation_b: int, amount: float) -> void:
	var key := _pair_key(nation_a, nation_b)
	tension[key] = clampf(tension.get(key, 0.0) + amount, 0.0, 100.0)
	changed.emit()


func get_active_war_between(nation_a: int, nation_b: int) -> War:
	for war: War in wars.values():
		if war.status != GameEnums.WarStatus.ACTIVE:
			continue
		if (war.attacker == nation_a and war.defender == nation_b) or (war.attacker == nation_b and war.defender == nation_a):
			return war
	return null


func get_war_status(nation_a: int, nation_b: int) -> int:
	return GameEnums.NationWarStatus.WAR if get_active_war_between(nation_a, nation_b) != null else GameEnums.NationWarStatus.PEACE


func is_at_war(nation_id: int) -> bool:
	var count := 0
	for war: War in wars.values():
		if war.status == GameEnums.WarStatus.ACTIVE and (war.attacker == nation_id or war.defender == nation_id):
			count += 1
	return count >= MAX_ACTIVE_WARS_PER_NATION


func declare_war(attacker: int, defender: int) -> War:
	var war := War.new()
	war.war_id = Util.generate_uuid()
	war.attacker = attacker
	war.defender = defender
	war.started_date = WorldTimeStore.get_display_string()
	war.battle_power_a = _initial_national_power(attacker)
	war.battle_power_b = _initial_national_power(defender)
	wars[war.war_id] = war
	WarBattleSpawner.spawn_battle(war)

	var text := "%s 對 %s 宣戰!" % [
		GameEnums.bloodline_nation_label(attacker), GameEnums.bloodline_nation_label(defender),
	]
	NewsController.post(text, GameEnums.NewsCategory.WAR)
	MessageBar.show_message(text)
	changed.emit()
	return war


## war_world_time_events.gd 的 monthly_tick() 結算完某一個 WarBattle 時呼叫(也可能是
## WarCampaignController 打完 10 連戰後當場分出勝負時呼叫):套用疲憊增量、把這場戰場
## 從 war.active_battles 移除——War 本身不受影響,繼續進行,WarBattleSpawner 照樣會在
## 額度內持續補新戰場,不是這場戰場結算戰爭就跟著結束。個別戰場結算不算重大到需要進消息
## 列表(NewsCategory.WAR 只留給整場 War 的宣戰/停戰),故意不呼叫 NewsController。
func settle_battle(war: War, battle: WarBattle, result: BattleResult) -> void:
	war.war_exhaustion_a = clampf(war.war_exhaustion_a + result.exhaustion_gain_a, 0.0, 100.0)
	war.war_exhaustion_b = clampf(war.war_exhaustion_b + result.exhaustion_gain_b, 0.0, 100.0)
	war.active_battles.erase(battle)
	battle.status = GameEnums.WarBattleStatus.ENDED
	changed.emit()


func resolve_truce(war: War) -> void:
	war.status = GameEnums.WarStatus.ENDED
	for battle: WarBattle in war.active_battles:
		battle.status = GameEnums.WarBattleStatus.ENDED
	war.active_battles.clear()
	_settle_war_contribution_reward(war)

	var key := _pair_key(war.attacker, war.defender)
	tension[key] = WarTruceRule.post_truce_tension(get_war_tension(war.attacker, war.defender))

	var text := "%s 與 %s 達成停戰協議。" % [
		GameEnums.bloodline_nation_label(war.attacker), GameEnums.bloodline_nation_label(war.defender),
	]
	NewsController.post(text, GameEnums.NewsCategory.WAR)
	MessageBar.show_message(text)
	changed.emit()


## 戰功換算成實際獎勵的唯一入口,只在停戰當下呼叫一次(見 resolve_truce())。玩家只要有
## 明確選邊(不是 SIDE_UNDECIDED/SIDE_NOT_PARTICIPATING)就一定會看到這場戰爭的結算——
## 不额外要求戰功 > 0,避免玩家選了邊卻完全沒被通知戰爭已經結束。用停戰當下雙方
## war_exhaustion 高低比判斷支援的國家有沒有贏:疲憊值較低代表這一路打下來損耗較少、相對
## 佔優,見 BattleResultGrader/WarExhaustionRule(贏的一方疲憊增量本來就比輸的一方少)。贏
## 才把累積戰功換算成金幣+好感度一次發放;沒贏(含平手)不發獎勵,但戰功本身已經是「打過」
## 的紀錄,不因此值不值得換算而消失。無論輸贏,War 結束後戰功都歸零、不跨場戰爭累積。結果
## 同時用 ActionPanel 彈窗顯示(不是一閃即逝的 MessageBar)跟寫進 NewsController(WAR
## 分類)——彈窗給當下的即時反饋,消息列表讓玩家事後還查得到領了多少獎勵。
func _settle_war_contribution_reward(war: War) -> void:
	var participated := war.player_side != War.SIDE_UNDECIDED and war.player_side != War.SIDE_NOT_PARTICIPATING
	if participated:
		var opponent := war.other_nation(war.player_side)
		var won := war.exhaustion_for(war.player_side) < war.exhaustion_for(opponent)
		var money := 0
		var favor := 0
		if won:
			money = WarContributionRule.money_for_contribution(war.player_war_contribution)
			favor = WarContributionRule.favor_for_contribution(war.player_war_contribution)
			BaseResourceStore.add(GameEnums.ResourceType.GOLD, money)
			if favor > 0:
				NationFavorStore.add_favor(war.player_side, favor)
		var text := _war_result_text(war.player_side, opponent, won, money, favor)
		NewsController.post(text, GameEnums.NewsCategory.WAR)
		_show_war_result_panel(war.player_side, opponent, won, money, favor)
	war.player_war_contribution = 0


func _war_result_text(supported_nation: int, opponent: int, won: bool, money: int, favor: int) -> String:
	if won:
		return "支援的 %s 贏得了與 %s 的戰爭!獲得戰功獎勵:%d 金幣、%d 好感度。" % [
			GameEnums.bloodline_nation_label(supported_nation), GameEnums.bloodline_nation_label(opponent), money, favor,
		]
	return "支援的 %s 未能贏得與 %s 的戰爭,沒有戰功獎勵。" % [
		GameEnums.bloodline_nation_label(supported_nation), GameEnums.bloodline_nation_label(opponent),
	]


func _show_war_result_panel(supported_nation: int, opponent: int, won: bool, money: int, favor: int) -> void:
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var summary_label := Label.new()
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	summary_label.add_theme_font_size_override("font_size", 18)
	summary_label.add_theme_color_override("font_color", UiStyle.PARCHMENT_TEXT_COLOR)
	if won:
		summary_label.text = "支援的 %s 贏得了與 %s 的戰爭!" % [
			GameEnums.bloodline_nation_label(supported_nation), GameEnums.bloodline_nation_label(opponent),
		]
	else:
		summary_label.text = "支援的 %s 未能贏得與 %s 的戰爭,沒有戰功獎勵。" % [
			GameEnums.bloodline_nation_label(supported_nation), GameEnums.bloodline_nation_label(opponent),
		]
	content.add_child(summary_label)

	if won:
		var reward_label := Label.new()
		reward_label.text = "戰功獎勵:%d 金幣、%d 好感度" % [money, favor]
		reward_label.add_theme_font_size_override("font_size", 16)
		reward_label.add_theme_color_override("font_color", UiStyle.PARCHMENT_SUBTITLE_COLOR)
		content.add_child(reward_label)

	ActionPanel.open_custom("戰爭結果", content)


## 唯一改動 War.player_side 的入口(比照 modify_war_tension() 的慣例)——整場戰爭只鎖
## 一次,見 System/event/map/war_battle_event.gd 的選邊敘事。
func set_player_side(war: War, side: int) -> void:
	war.player_side = side
	var text: String
	if side == War.SIDE_NOT_PARTICIPATING:
		text = "你決定不插手 %s 與 %s 的戰爭。" % [
			GameEnums.bloodline_nation_label(war.attacker), GameEnums.bloodline_nation_label(war.defender),
		]
	else:
		text = "你決定支援 %s。" % GameEnums.bloodline_nation_label(side)
	MessageBar.show_message(text)
	changed.emit()


func get_active_war_battles() -> Array[WarBattle]:
	var battles: Array[WarBattle] = []
	for war: War in wars.values():
		battles.append_array(war.active_battles)
	return battles


func find_war_battle(battle_id: String) -> WarBattle:
	for battle in get_active_war_battles():
		if battle.battle_id == battle_id:
			return battle
	return null


func find_war(war_id: String) -> War:
	return wars.get(war_id)


## 沒有既有的「國力」數值可用,先讓所有國家戰爭起點對等,之後有更豐富的國力資料
## (人口/建築/軍力科技等)再取代這個 placeholder。
func _initial_national_power(_nation_id: int) -> float:
	return 100.0


func to_save_data() -> Dictionary:
	var wars_data: Dictionary = {}
	for war_id in wars:
		wars_data[war_id] = _encode_war(wars[war_id])
	return {"tension": tension.duplicate(), "wars": wars_data}


func load_save_data(data: Dictionary) -> void:
	tension = (data.get("tension", {}) as Dictionary).duplicate()
	wars = {}
	var wars_data: Dictionary = data.get("wars", {})
	for war_id in wars_data:
		wars[war_id] = _decode_war(wars_data[war_id])
	changed.emit()


func _encode_war(war: War) -> Dictionary:
	var battles_data: Array = []
	for battle in war.active_battles:
		battles_data.append(_encode_battle(battle))
	return {
		"war_id": war.war_id, "attacker": war.attacker, "defender": war.defender,
		"started_date": war.started_date,
		"war_exhaustion_a": war.war_exhaustion_a, "war_exhaustion_b": war.war_exhaustion_b,
		"battle_power_a": war.battle_power_a, "battle_power_b": war.battle_power_b, "status": war.status,
		"next_battle_spawn_day": war.next_battle_spawn_day,
		"player_side": war.player_side, "player_war_contribution": war.player_war_contribution,
		"active_battles": battles_data,
	}


func _decode_war(data: Dictionary) -> War:
	var war := War.new()
	war.war_id = data["war_id"]
	war.attacker = int(data["attacker"])
	war.defender = int(data["defender"])
	war.started_date = data.get("started_date", "")
	war.war_exhaustion_a = float(data.get("war_exhaustion_a", 0.0))
	war.war_exhaustion_b = float(data.get("war_exhaustion_b", 0.0))
	war.battle_power_a = float(data.get("battle_power_a", 0.0))
	war.battle_power_b = float(data.get("battle_power_b", 0.0))
	war.status = int(data.get("status", GameEnums.WarStatus.ACTIVE))
	war.next_battle_spawn_day = int(data.get("next_battle_spawn_day", -1))
	war.player_side = int(data.get("player_side", War.SIDE_UNDECIDED))
	war.player_war_contribution = int(data.get("player_war_contribution", 0))
	var battles_data: Array = data.get("active_battles", [])
	war.active_battles = []
	for battle_data in battles_data:
		war.active_battles.append(_decode_battle(battle_data))
	return war


func _encode_battle(battle: WarBattle) -> Dictionary:
	return {
		"battle_id": battle.battle_id, "war_id": battle.war_id,
		"position": [battle.position.x, battle.position.y],
		"nation_a": battle.nation_a, "nation_b": battle.nation_b,
		"battle_power_a": battle.battle_power_a, "battle_power_b": battle.battle_power_b,
		"battle_progress": battle.battle_progress, "duration_months": battle.duration_months,
		"status": battle.status, "rank_type": battle.rank_type, "max_duration_months": battle.max_duration_months,
	}


func _decode_battle(data: Dictionary) -> WarBattle:
	var battle := WarBattle.new()
	battle.battle_id = data["battle_id"]
	battle.war_id = data["war_id"]
	var pos: Array = data["position"]
	battle.position = Vector2(pos[0], pos[1])
	battle.nation_a = int(data["nation_a"])
	battle.nation_b = int(data["nation_b"])
	battle.battle_power_a = float(data["battle_power_a"])
	battle.battle_power_b = float(data["battle_power_b"])
	battle.battle_progress = float(data.get("battle_progress", 0.0))
	battle.duration_months = int(data.get("duration_months", 0))
	battle.status = int(data.get("status", GameEnums.WarBattleStatus.ACTIVE))
	battle.rank_type = int(data.get("rank_type", GameEnums.RankType.F))
	battle.max_duration_months = int(data.get("max_duration_months", 1))
	return battle
