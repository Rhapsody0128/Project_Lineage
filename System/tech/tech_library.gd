class_name TechLibrary
extends RefCounted

## 科技樹全資料:三大分類(GameEnums.TechBranch)各 10 條機制鏈、30 個節點,共 90 個。
## 平衡數值全部集中在這個檔案的 Entry.new() 呼叫——調一條鏈的效果/rank 只要改對應那一行,
## id/前置關係/科研花費都是自動算出來的,不用手動維護。
##
## 設計規則(完整脈絡見設計文件,這裡只記程式要遵守的部分):
## - 解鎖條件只有兩個:A. 科學研究所等級 ≥ node.required_institute_level();
##   B. node.prerequisite_id 對應節點已解鎖(鏈首 prerequisite_id 為空字串,不需要)。
##   不綁定任何其他建築。
## - 每條「機制鏈」是同一個效果在不同 rank 疊層,鏈內 rank 嚴格遞增,effect_value 是
##   「這一層自己的增量」不是累計值——TechStore.get_bonus() 會把同一 effect_type 的所有
##   已解鎖節點加總,加總結果才是玩家實際拿到的累計效果。
## - 科研花費 = cost_for_rank(rank) = 10 × 1.7^rank 四捨五入到 5(F=10...SSS=700),
##   換算依據見設計文件的「科研產出速率評估」——後期月收入抓 65 科研,一年存款約可買
##   一個 SSS 節點。
## - card_description 刻意不寫確切數值(卡片只給方向感),確切數值/機率寫在
##   effect_detail,給之後可能的詳情面板或工具提示用。


class Entry:
	var rank: int
	var name: String
	var card: String
	var detail: String
	var effect_type: int
	var value: float

	func _init(p_rank: int, p_name: String, p_card: String, p_detail: String, p_effect_type: int, p_value: float) -> void:
		rank = p_rank
		name = p_name
		card = p_card
		detail = p_detail
		effect_type = p_effect_type
		value = p_value


const COST_BASE := 10.0
const COST_GROWTH := 1.7


## F=10、E=15、D=30、C=50、B=85、A=140、S=240、SS=410、SSS=700。
static func cost_for_rank(rank: int) -> int:
	return roundi(COST_BASE * pow(COST_GROWTH, rank) / 5.0) * 5


## 组一條機制鏈:entries 裡的 rank 必須嚴格遞增(同一條鏈不能有兩層卡在同一個科學研究所
## 等級門檻上,那樣會浪費一個 rank 檔位),否則直接 assert 擋下來,不會生成看起來正常但
## 邏輯有問題的資料。
static func _thread(branch: int, thread_name: String, dev_note: String, feasibility: String, entries: Array[Entry]) -> Array[TechNode]:
	var nodes: Array[TechNode] = []
	var prev_id := ""
	for i in range(entries.size()):
		var entry := entries[i]
		if i > 0:
			assert(entry.rank > entries[i - 1].rank, "TechLibrary: 「%s」機制鏈 rank 必須嚴格遞增" % thread_name)
		var id := "%s.%s.%d" % [GameEnums.TechBranch.keys()[branch], thread_name, i]
		var node := TechNode.new(
			id, branch, thread_name, entry.rank, i + 1, entries.size(),
			entry.name, entry.card, entry.detail, entry.effect_type, entry.value,
			prev_id, cost_for_rank(entry.rank), dev_note, feasibility
		)
		nodes.append(node)
		prev_id = id
	return nodes


static func get_combat() -> Array[TechNode]:
	var branch := GameEnums.TechBranch.COMBAT
	var nodes: Array[TechNode] = []

	nodes.append_array(_thread(branch, "鍛造節約", "WeaponLibrary.CRAFT_ORE_COST_BY_RANK", "low", [
		Entry.new(GameEnums.RankType.F, "節約鍛造", "降低打造武器所需的鐵礦。", "打造武器耗鐵礦 -1,不分打造品階。", GameEnums.TechEffectType.WEAPON_CRAFT_ORE_COST_SUB, 1.0),
		Entry.new(GameEnums.RankType.D, "精煉工序", "打造耗礦再降低一些。", "耗鐵礦再 -1(累計 -2)。", GameEnums.TechEffectType.WEAPON_CRAFT_ORE_COST_SUB, 1.0),
		Entry.new(GameEnums.RankType.B, "巧手匠人", "頂級鍛造流程明顯省料,全鏈頂點。", "耗鐵礦再 -2(累計 -4)。", GameEnums.TechEffectType.WEAPON_CRAFT_ORE_COST_SUB, 2.0),
	]))

	nodes.append_array(_thread(branch, "銳鋒精進", "CombatResolver.judge_crit() 的 CRIT_RATE_BASE", "low", [
		Entry.new(GameEnums.RankType.E, "刃疾如風", "提升戰鬥暴擊率。", "戰鬥暴擊率基準 +2%(15%→17%)。", GameEnums.TechEffectType.CRIT_RATE_BASE_ADD, 2.0),
		Entry.new(GameEnums.RankType.C, "電光石火", "暴擊率再提升一階。", "暴擊率基準再 +2%(→19%)。", GameEnums.TechEffectType.CRIT_RATE_BASE_ADD, 2.0),
		Entry.new(GameEnums.RankType.A, "一擊必殺之志", "暴擊率再提升一階。", "暴擊率基準再 +2%(→21%)。", GameEnums.TechEffectType.CRIT_RATE_BASE_ADD, 2.0),
		Entry.new(GameEnums.RankType.SS, "修羅之眼", "暴擊率顯著提升。", "暴擊率基準再 +3%(→24%),漲幅開始拉大。", GameEnums.TechEffectType.CRIT_RATE_BASE_ADD, 3.0),
		Entry.new(GameEnums.RankType.SSS, "弒神一擊", "暴擊率大幅躍升,全鏈頂點。", "暴擊率基準再 +4%(→28%)。", GameEnums.TechEffectType.CRIT_RATE_BASE_ADD, 4.0),
	]))

	nodes.append_array(_thread(branch, "鍛造精研", "WeaponLibrary.MAIN_STAT_WEIGHT_BONUS 與 ROLL_COUNT_RANGE 各檔上限", "mid", [
		Entry.new(GameEnums.RankType.D, "精準辨材", "打造抽點更容易命中武器主屬性。", "鐵匠鋪打造抽點時,武器主屬性的權重加成 +1(2→3)。", GameEnums.TechEffectType.WEAPON_MAIN_STAT_WEIGHT_ADD, 1.0),
		Entry.new(GameEnums.RankType.C, "精工圖紙", "增加打造抽點次數上限。", "打造抽點次數上限 +1。", GameEnums.TechEffectType.WEAPON_ROLL_COUNT_ADD, 1.0),
		Entry.new(GameEnums.RankType.B, "匠心獨運", "命中主屬性的機率再提升。", "主屬性權重加成再 +2(累計 →5)。", GameEnums.TechEffectType.WEAPON_MAIN_STAT_WEIGHT_ADD, 2.0),
		Entry.new(GameEnums.RankType.S, "巨匠秘傳", "抽點次數上限再提升,全鏈頂點。", "抽點次數上限再 +2(累計 +3)。", GameEnums.TechEffectType.WEAPON_ROLL_COUNT_ADD, 2.0),
	]))

	nodes.append_array(_thread(branch, "傳習革新", "BarracksTeachingRule.MIN_TEACHER_AGE_BY_RANK", "low", [
		Entry.new(GameEnums.RankType.C, "兵法傳習", "降低傳授技能的師徒年齡限制。", "兵營「傳授」師父年齡門檻整表 -5 歲。", GameEnums.TechEffectType.TEACH_AGE_THRESHOLD_SUB, 5.0),
		Entry.new(GameEnums.RankType.A, "桃李滿門", "年齡限制再大幅放寬,全鏈頂點。", "年齡門檻再 -8 歲(累計 -13 歲)。", GameEnums.TechEffectType.TEACH_AGE_THRESHOLD_SUB, 8.0),
	]))

	nodes.append_array(_thread(branch, "統御節流", "LeaderTrainingRule.cost_for_skill()", "low", [
		Entry.new(GameEnums.RankType.B, "統御之道", "降低隊長訓練花費。", "兵營「隊長訓練」花費金錢 -10%。", GameEnums.TechEffectType.LEADER_TRAINING_COST_MULT_SUB, 0.10),
		Entry.new(GameEnums.RankType.SS, "王者之道", "訓練花費再大幅降低,全鏈頂點。", "花費再 -15%(累計 -25%)。", GameEnums.TechEffectType.LEADER_TRAINING_COST_MULT_SUB, 0.15),
	]))

	nodes.append_array(_thread(branch, "疾行軍略", "world_inner.gd 的 move_delta 乘數", "low", [
		Entry.new(GameEnums.RankType.F, "輕裝上陣", "提升大地圖移動速度。", "大地圖移動速度 +5%。", GameEnums.TechEffectType.MOVE_SPEED_MULT_ADD, 0.05),
		Entry.new(GameEnums.RankType.C, "快速野營", "移動速度再提升。", "移動速度再 +5%(累計 10%)。", GameEnums.TechEffectType.MOVE_SPEED_MULT_ADD, 0.05),
		Entry.new(GameEnums.RankType.S, "急行軍", "移動速度再提升。", "移動速度再 +5%(累計 15%)。", GameEnums.TechEffectType.MOVE_SPEED_MULT_ADD, 0.05),
		Entry.new(GameEnums.RankType.SSS, "天下無雙之疾", "移動速度大幅躍升,全鏈頂點。", "移動速度再 +10%(累計 25%)。", GameEnums.TechEffectType.MOVE_SPEED_MULT_ADD, 0.10),
	]))

	nodes.append_array(_thread(branch, "戰陣迴避", "CombatResolver.judge_dodge() 的 DODGE_RATE_BASE", "low", [
		Entry.new(GameEnums.RankType.B, "側身閃避", "提升戰場基礎閃避率。", "戰場基礎閃避率 +2%(10%→12%)。", GameEnums.TechEffectType.DODGE_RATE_BASE_ADD, 2.0),
		Entry.new(GameEnums.RankType.A, "靈風步", "閃避率再提升。", "基礎閃避率再 +2%(→14%)。", GameEnums.TechEffectType.DODGE_RATE_BASE_ADD, 2.0),
		Entry.new(GameEnums.RankType.SS, "縱橫捭闔", "閃避率顯著提升,全鏈頂點。", "基礎閃避率再 +4%(→18%)。", GameEnums.TechEffectType.DODGE_RATE_BASE_ADD, 4.0),
	]))

	nodes.append_array(_thread(branch, "暴擊深化", "CombatResolver.CRIT_DAMAGE_MULTIPLIER", "low", [
		Entry.new(GameEnums.RankType.S, "破軍之勢", "提升暴擊傷害倍率。", "暴擊傷害倍率 +0.1(1.6×→1.7×)。", GameEnums.TechEffectType.CRIT_DAMAGE_MULTIPLIER_ADD, 0.1),
		Entry.new(GameEnums.RankType.SSS, "常勝威名", "暴擊傷害倍率大幅提升,全鏈頂點。", "暴擊傷害倍率再 +0.2(→1.9×)。", GameEnums.TechEffectType.CRIT_DAMAGE_MULTIPLIER_ADD, 0.2),
	]))

	nodes.append_array(_thread(branch, "輕裝遠征", "BarracksExpeditionStore 倒數天數常數(需先拆出獨立常數)", "mid", [
		Entry.new(GameEnums.RankType.C, "輕裝遠征", "縮短兵營歷練所需天數。", "兵營「歷練」所需天數 -15 天。", GameEnums.TechEffectType.EXPEDITION_DURATION_DAYS_SUB, 15.0),
		Entry.new(GameEnums.RankType.S, "兵貴神速", "歷練天數再縮短,全鏈頂點。", "天數再 -20 天(累計 -35 天)。", GameEnums.TechEffectType.EXPEDITION_DURATION_DAYS_SUB, 20.0),
	]))

	nodes.append_array(_thread(branch, "料敵先機", "CombatResolver.judge_reactive_trigger() 內部加上固定加成後再骰", "low", [
		Entry.new(GameEnums.RankType.E, "料敵先機", "提升反應式技能觸發機率。", "全體「反應式」判定(守護/會心反擊/完美閃避/持續治療等武器被動)觸發機率 +5%。", GameEnums.TechEffectType.REACTIVE_TRIGGER_RATE_ADD, 5.0),
		Entry.new(GameEnums.RankType.B, "見微知著", "觸發機率再提升。", "觸發機率再 +5%(累計 10%)。", GameEnums.TechEffectType.REACTIVE_TRIGGER_RATE_ADD, 5.0),
		Entry.new(GameEnums.RankType.SS, "料事如神", "觸發機率顯著提升,全鏈頂點。", "觸發機率再 +10%(累計 20%)。", GameEnums.TechEffectType.REACTIVE_TRIGGER_RATE_ADD, 10.0),
	]))

	return nodes


static func get_domestic() -> Array[TechNode]:
	var branch := GameEnums.TechBranch.DOMESTIC
	var nodes: Array[TechNode] = []

	nodes.append_array(_thread(branch, "營建效率", "BaseBuildingProgressStore.get_upgrade_days()", "low", [
		Entry.new(GameEnums.RankType.F, "動工便利", "縮短建築升級天數。", "全建築升級所需天數 -5%。", GameEnums.TechEffectType.BUILDING_UPGRADE_DAYS_MULT_SUB, 0.05),
		Entry.new(GameEnums.RankType.C, "速成工法", "升級天數再縮短。", "升級天數再 -5%(累計 10%)。", GameEnums.TechEffectType.BUILDING_UPGRADE_DAYS_MULT_SUB, 0.05),
		Entry.new(GameEnums.RankType.S, "星夜趕工", "升級天數再縮短。", "升級天數再 -5%(累計 15%)。", GameEnums.TechEffectType.BUILDING_UPGRADE_DAYS_MULT_SUB, 0.05),
		Entry.new(GameEnums.RankType.SSS, "基業永固", "升級天數大幅縮短,全鏈頂點。", "升級天數再 -10%(累計 25%)。", GameEnums.TechEffectType.BUILDING_UPGRADE_DAYS_MULT_SUB, 0.10),
	]))

	nodes.append_array(_thread(branch, "產業精進", "BaseProduction.monthly_yield_for_worker()", "low", [
		Entry.new(GameEnums.RankType.E, "精簡工序", "提升全體生產建築月產出。", "全 12 棟生產建築(含科學研究所)月產出 +3%。", GameEnums.TechEffectType.PRODUCTION_YIELD_MULT_ADD, 0.03),
		Entry.new(GameEnums.RankType.B, "產業革新", "產出再提升。", "產出再 +3%(累計 6%)。", GameEnums.TechEffectType.PRODUCTION_YIELD_MULT_ADD, 0.03),
		Entry.new(GameEnums.RankType.A, "量產工法", "產出再提升。", "產出再 +3%(累計 9%)。", GameEnums.TechEffectType.PRODUCTION_YIELD_MULT_ADD, 0.03),
		Entry.new(GameEnums.RankType.SSS, "產業革命", "產出大幅提升,全鏈頂點。", "產出再 +6%(累計 15%)。", GameEnums.TechEffectType.PRODUCTION_YIELD_MULT_ADD, 0.06),
	]))

	nodes.append_array(_thread(branch, "資材節約", "BaseBuildingProgressStore.get_upgrade_cost()", "low", [
		Entry.new(GameEnums.RankType.D, "資材節約", "降低建築升級耗材。", "全建築升級耗材 -5%。", GameEnums.TechEffectType.BUILDING_UPGRADE_COST_MULT_SUB, 0.05),
		Entry.new(GameEnums.RankType.S, "精打細算", "耗材再大幅降低,全鏈頂點。", "耗材再 -8%(累計 13%)。", GameEnums.TechEffectType.BUILDING_UPGRADE_COST_MULT_SUB, 0.08),
	]))

	nodes.append_array(_thread(branch, "倉儲擴建", "BaseWarehouse.get_capacity()", "low", [
		Entry.new(GameEnums.RankType.C, "磚石儲備", "提升倉庫容量。", "倉庫各項資源容量 +10%。", GameEnums.TechEffectType.WAREHOUSE_CAPACITY_MULT_ADD, 0.10),
		Entry.new(GameEnums.RankType.B, "深挖地窖", "容量再提升。", "容量再 +10%(累計 20%)。", GameEnums.TechEffectType.WAREHOUSE_CAPACITY_MULT_ADD, 0.10),
		Entry.new(GameEnums.RankType.SS, "大型倉儲", "容量顯著提升。", "容量再 +15%(累計 35%)。", GameEnums.TechEffectType.WAREHOUSE_CAPACITY_MULT_ADD, 0.15),
		Entry.new(GameEnums.RankType.SSS, "永世珍藏", "容量大幅提升,全鏈頂點。", "容量再 +25%(累計 60%)。", GameEnums.TechEffectType.WAREHOUSE_CAPACITY_MULT_ADD, 0.25),
	]))

	nodes.append_array(_thread(branch, "住宅規劃", "base_building_progress_store.gd 的 20+20×Lv 公式", "low", [
		Entry.new(GameEnums.RankType.B, "住宅規劃", "提升住宅區容量。", "住宅區容量額外 +10。", GameEnums.TechEffectType.RESIDENTIAL_CAPACITY_ADD, 10.0),
		Entry.new(GameEnums.RankType.A, "里坊擴建", "容量再提升。", "容量再 +10(累計 +20)。", GameEnums.TechEffectType.RESIDENTIAL_CAPACITY_ADD, 10.0),
		Entry.new(GameEnums.RankType.S, "都市計畫", "容量再顯著提升。", "容量再 +15(累計 +35)。", GameEnums.TechEffectType.RESIDENTIAL_CAPACITY_ADD, 15.0),
		Entry.new(GameEnums.RankType.SSS, "廣廈千萬", "容量再大幅提升,全鏈頂點。", "容量再 +15(累計 +50)。", GameEnums.TechEffectType.RESIDENTIAL_CAPACITY_ADD, 15.0),
	]))

	nodes.append_array(_thread(branch, "輕裝遷徙", "BaseRelocationRule.COST", "low", [
		Entry.new(GameEnums.RankType.B, "輕裝遷徙", "降低根據地遷移花費。", "根據地遷移花費(木材/石材)各 -100(500→400)。", GameEnums.TechEffectType.RELOCATION_COST_SUB, 100.0),
		Entry.new(GameEnums.RankType.SSS, "舉族西遷", "遷移花費再大幅降低,全鏈頂點。", "遷移花費再各 -150(→250)。", GameEnums.TechEffectType.RELOCATION_COST_SUB, 150.0),
	]))

	nodes.append_array(_thread(branch, "配方革新", "WorkshopRecipe / WorkshopProduction 換算函式", "mid", [
		Entry.new(GameEnums.RankType.C, "配方優化", "消耗型配方多一些產出。", "消耗型配方(伐木/採礦/黑市等)多產出 1 單位。", GameEnums.TechEffectType.RECIPE_EXTRA_OUTPUT_ADD, 1.0),
		Entry.new(GameEnums.RankType.A, "精煉配方", "配方產出再提升。", "再多產出 1 單位。", GameEnums.TechEffectType.RECIPE_EXTRA_OUTPUT_ADD, 1.0),
		Entry.new(GameEnums.RankType.SSS, "點石成金", "配方產出大幅提升,全鏈頂點。", "再多產出 2 單位(累計 +4)。", GameEnums.TechEffectType.RECIPE_EXTRA_OUTPUT_ADD, 2.0),
	]))

	nodes.append_array(_thread(branch, "匠人熟練", "BaseProduction.character_efficiency() 的基準值 0.5", "low", [
		Entry.new(GameEnums.RankType.A, "熟練工匠", "提升派駐角色的基礎效率。", "派駐效率基準 +0.05(0.5→0.55)。", GameEnums.TechEffectType.CHARACTER_EFFICIENCY_BASE_ADD, 0.05),
		Entry.new(GameEnums.RankType.SSS, "一代宗師", "基礎效率再大幅提升,全鏈頂點。", "基準再 +0.08(→0.63)。", GameEnums.TechEffectType.CHARACTER_EFFICIENCY_BASE_ADD, 0.08),
	]))

	nodes.append_array(_thread(branch, "廣納賢才", "BaseBuildingProgressStore.get_max_workers()", "low", [
		Entry.new(GameEnums.RankType.SSS, "廣納賢才", "提升生產建築派駐人數上限。", "全 12 棟生產建築(含科學研究所)可派駐人數上限額外 +1。", GameEnums.TechEffectType.MAX_WORKERS_ADD, 1.0),
	]))

	nodes.append_array(_thread(branch, "市集通商", "BaseExchange.route_count()/route_capacity()", "mid", [
		Entry.new(GameEnums.RankType.D, "市集通商", "商隊站與黑市各自新增一條自動兌換路線。", "「每月自動兌換」路線數量 +1(基礎 1 條→2 條),新路線可與既有路線同時交易不同資材,互不共用額度。", GameEnums.TechEffectType.EXCHANGE_ROUTE_COUNT_ADD, 1.0),
		Entry.new(GameEnums.RankType.B, "八方商道", "貿易路線再增開一條。", "路線數量再 +1(累計 3 條)。", GameEnums.TechEffectType.EXCHANGE_ROUTE_COUNT_ADD, 1.0),
		Entry.new(GameEnums.RankType.S, "萬商雲集", "貿易路線再增開一條。", "路線數量再 +1(累計 4 條)。", GameEnums.TechEffectType.EXCHANGE_ROUTE_COUNT_ADD, 1.0),
		Entry.new(GameEnums.RankType.SSS, "貨暢其流", "貿易路線增至上限,全鏈頂點。", "路線數量再 +1(累計 5 條:基礎 1 條 + 科技 4 條)。", GameEnums.TechEffectType.EXCHANGE_ROUTE_COUNT_ADD, 1.0),
	]))

	return nodes


static func get_knowledge() -> Array[TechNode]:
	var branch := GameEnums.TechBranch.KNOWLEDGE
	var nodes: Array[TechNode] = []

	nodes.append_array(_thread(branch, "醫術精進", "WorldTimeEventLibrary._regen_hp() 的 amount", "low", [
		Entry.new(GameEnums.RankType.F, "草藥知識", "提升角色每日 HP 回復。", "角色每日 HP 回復基準 +1。", GameEnums.TechEffectType.HP_REGEN_DAILY_ADD, 1.0),
		Entry.new(GameEnums.RankType.D, "藥理研究", "回復再提升。", "回復基準再 +1。", GameEnums.TechEffectType.HP_REGEN_DAILY_ADD, 1.0),
		Entry.new(GameEnums.RankType.B, "妙手回春", "回復再提升。", "回復基準再 +1。", GameEnums.TechEffectType.HP_REGEN_DAILY_ADD, 1.0),
		Entry.new(GameEnums.RankType.SS, "醫者仁心", "回復顯著提升。", "回復基準再 +2(累計 +5)。", GameEnums.TechEffectType.HP_REGEN_DAILY_ADD, 2.0),
		Entry.new(GameEnums.RankType.SSS, "華佗再世", "回復再大幅提升,全鏈頂點。", "回復基準再 +2(累計 +7)。", GameEnums.TechEffectType.HP_REGEN_DAILY_ADD, 2.0),
	]))

	nodes.append_array(_thread(branch, "婚姻禮制", "MarriageQuotaRule.max_quota_per_year();成功率層見 MarriageRule.acceptance_chance() 的 20.0 與 ALLIANCE_SUCCESS_CHANCE_PERCENT 的 50.0", "low", [
		Entry.new(GameEnums.RankType.E, "婚姻禮制", "增加城鎮中心聯姻名額。", "城鎮中心每年聯姻名額額外 +1。", GameEnums.TechEffectType.MARRIAGE_QUOTA_ADD, 1.0),
		Entry.new(GameEnums.RankType.D, "良緣天成", "提升聯姻與告白成功率。", "所有聯姻/告白的成功率統一 +10%:酒館反告白 20%→30%,城鎮中心聯姻 50%→60%。", GameEnums.TechEffectType.MARRIAGE_SUCCESS_CHANCE_ADD, 10.0),
		Entry.new(GameEnums.RankType.B, "天作之合", "成功率再大幅提升。", "成功率再統一 +15%(→45%／→75%)。", GameEnums.TechEffectType.MARRIAGE_SUCCESS_CHANCE_ADD, 15.0),
		Entry.new(GameEnums.RankType.S, "姻緣廣傳", "聯姻名額再提升,全鏈頂點。", "聯姻名額再 +2(累計 +3)。", GameEnums.TechEffectType.MARRIAGE_QUOTA_ADD, 2.0),
	]))

	nodes.append_array(_thread(branch, "延年益壽", "AgingRule.get_aging_line() / get_death_line()", "low", [
		Entry.new(GameEnums.RankType.D, "基礎診療", "延後衰老與死亡年齡線。", "衰老線／死亡線各再延後 +2 歲。", GameEnums.TechEffectType.AGING_DEATH_LINE_ADD, 2.0),
		Entry.new(GameEnums.RankType.B, "延年之術", "年齡線再延後。", "各再 +2 歲(累計 +4)。", GameEnums.TechEffectType.AGING_DEATH_LINE_ADD, 2.0),
		Entry.new(GameEnums.RankType.A, "長生秘方", "年齡線再延後。", "各再 +2 歲(累計 +6)。", GameEnums.TechEffectType.AGING_DEATH_LINE_ADD, 2.0),
		Entry.new(GameEnums.RankType.SSS, "返老還童", "年齡線大幅延後,全鏈頂點。", "各再 +4 歲(累計 +10)。", GameEnums.TechEffectType.AGING_DEATH_LINE_ADD, 4.0),
	]))

	nodes.append_array(_thread(branch, "孕育之道", "PregnancyRule.get_pregnancy_chance_percent()", "low", [
		Entry.new(GameEnums.RankType.C, "孕育之學", "提升每月懷孕機率。", "每月懷孕機率基準 +3%(15%→18%)。", GameEnums.TechEffectType.PREGNANCY_CHANCE_ADD, 3.0),
		Entry.new(GameEnums.RankType.A, "天賜麟兒", "機率再提升。", "機率再 +3%(累計 6%)。", GameEnums.TechEffectType.PREGNANCY_CHANCE_ADD, 3.0),
		Entry.new(GameEnums.RankType.SS, "人丁興旺", "機率顯著提升,全鏈頂點。", "機率再 +5%(累計 11%)。", GameEnums.TechEffectType.PREGNANCY_CHANCE_ADD, 5.0),
	]))

	nodes.append_array(_thread(branch, "血統純化", "InheritanceConstants.BLOODLINE_MUTATION_CHANCES", "low", [
		Entry.new(GameEnums.RankType.B, "純化儀式", "血統遺傳更容易產生變異。", "血統遺傳的變異機率往「輕微/大變異」偏移一階。", GameEnums.TechEffectType.BLOODLINE_MUTATION_SHIFT_ADD, 1.0),
		Entry.new(GameEnums.RankType.S, "血統躍升", "變異機率大幅偏移,全鏈頂點。", "一次偏移兩階,大變異機率顯著提升。", GameEnums.TechEffectType.BLOODLINE_MUTATION_SHIFT_ADD, 2.0),
	]))

	nodes.append_array(_thread(branch, "抗老醫理", "AgingRule.get_death_chance_percent() 回傳值(連乘,見 TechStore.get_multiplier())", "low", [
		Entry.new(GameEnums.RankType.A, "精準診斷", "降低老年死亡機率。", "老年死亡機率曲線整體 ×0.9。", GameEnums.TechEffectType.DEATH_CHANCE_CURVE_MULT, 0.9),
		Entry.new(GameEnums.RankType.SSS, "妙手回天", "死亡機率再降低,全鏈頂點。", "再 ×0.8(累計 ×0.72)。", GameEnums.TechEffectType.DEATH_CHANCE_CURVE_MULT, 0.8),
	]))

	nodes.append_array(_thread(branch, "血脈天賦", "InheritanceController.create_child() 呼叫 TraitController.get_random_traits() 的參數", "low", [
		Entry.new(GameEnums.RankType.A, "血脈天賦", "增加新生兒天生特質數量。", "新生兒天生特質數量 +1(2→3)。", GameEnums.TechEffectType.NEWBORN_TRAIT_COUNT_ADD, 1.0),
		Entry.new(GameEnums.RankType.SS, "造化鍾靈", "特質數量再提升。", "特質數量再 +1(→4)。", GameEnums.TechEffectType.NEWBORN_TRAIT_COUNT_ADD, 1.0),
		Entry.new(GameEnums.RankType.SSS, "麒麟天授", "特質數量再提升,全鏈頂點(設計上限 5)。", "特質數量再 +1(→5,設計上限)。", GameEnums.TechEffectType.NEWBORN_TRAIT_COUNT_ADD, 1.0),
	]))

	nodes.append_array(_thread(branch, "產後調理", "PregnancyRule.POSTPARTUM_MONTHS", "low", [
		Entry.new(GameEnums.RankType.D, "產後調理", "縮短產後休養期。", "產後休養期 -1 個月。", GameEnums.TechEffectType.POSTPARTUM_MONTHS_SUB, 1.0),
		Entry.new(GameEnums.RankType.B, "悉心療養", "休養期再縮短。", "休養期再 -1 個月(累計 -2)。", GameEnums.TechEffectType.POSTPARTUM_MONTHS_SUB, 1.0),
		Entry.new(GameEnums.RankType.S, "無憂產房", "休養期再縮短,全鏈頂點。", "休養期再 -1 個月(累計 -3)。", GameEnums.TechEffectType.POSTPARTUM_MONTHS_SUB, 1.0),
	]))

	nodes.append_array(_thread(branch, "老當益壯", "AgingRule.AGING_STAT_MULTIPLIER", "low", [
		Entry.new(GameEnums.RankType.C, "老當益壯", "減緩衰老後的素質下降。", "衰老特性的素質倍率 +0.03(0.7→0.73)。", GameEnums.TechEffectType.AGING_STAT_MULTIPLIER_ADD, 0.03),
		Entry.new(GameEnums.RankType.A, "老驥伏櫪", "素質下降再減緩,全鏈頂點。", "倍率再 +0.05(→0.78)。", GameEnums.TechEffectType.AGING_STAT_MULTIPLIER_ADD, 0.05),
	]))

	nodes.append_array(_thread(branch, "遊學新制", "AcademyRule.enroll() 呼叫 SkillController 的次數與挑選邏輯", "mid", [
		Entry.new(GameEnums.RankType.A, "留學新制", "留學初始技能多一次重骰機會。", "新生兒留學決定國家後,初始技能表改骰兩次取較好的一份。", GameEnums.TechEffectType.ACADEMY_REROLL_COUNT_ADD, 1.0),
		Entry.new(GameEnums.RankType.SSS, "名師出高徒", "重骰機會再增加,全鏈頂點。", "再骰一次,系統自動從三份候選中取最好的一份。", GameEnums.TechEffectType.ACADEMY_REROLL_COUNT_ADD, 1.0),
	]))

	return nodes


static func get_all() -> Array[TechNode]:
	var nodes: Array[TechNode] = []
	nodes.append_array(get_combat())
	nodes.append_array(get_domestic())
	nodes.append_array(get_knowledge())
	return nodes


static func get_by_branch(branch: GameEnums.TechBranch) -> Array[TechNode]:
	match branch:
		GameEnums.TechBranch.COMBAT:
			return get_combat()
		GameEnums.TechBranch.DOMESTIC:
			return get_domestic()
		_:
			return get_knowledge()


static func get_by_id(id: String) -> TechNode:
	for node in get_all():
		if node.id == id:
			return node
	return null
