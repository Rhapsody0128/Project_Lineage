class_name GameEnums
extends RefCounted

enum RankType {F, E, D, C, B, A, S, SS, SSS}
enum PotentialType {STRENGTH, VITALITY, AGILITY, DEXTERITY, INTELLIGENCE, MENTALITY}
enum WeaponType {SWORD, BOW, SHIELD, DAGGER, STAFF, DREAMCATCHER}
## Skill.bind_weapon 專用的「未綁定特定武器」標記(被動/隊長技能等任何武器都能用),
## 故意不塞進 WeaponType enum——角色一定持有真實武器,WeaponType 只代表可持有的
## 武器種類,不該混入這種非武器的旗標值。
const NO_WEAPON_BINDING := -1
## 角色清單排序欄位(PartyEdit 候補清單/未來其他角色清單共用,見 CharacterSortFilter),
## 前三項是衍生值,後六項對應 PotentialType 六大素質
enum CharacterSortKey {LEVEL, TOTAL_POTENTIAL, CELL_COUNT, STRENGTH, VITALITY, AGILITY, DEXTERITY, INTELLIGENCE, MENTALITY}
## 大地圖上的地點類型,見 System/map/map_object.gd
enum MapObjectType {TOWN, BASE, CASTLE}

## 角色目前狀態,見 System/character/character_status_rule.gd(唯一判定/顯示入口)。
## ACTIVE 服役中(在角色池,沒有派遣/離隊/死亡以外的特殊狀態);STATIONED 駐守中
## (未來城鎮駐守機制預留,目前沒有任何流程會產生這個值);WORKING 派駐在根據地建築
## 生產中(顯示文字要內插建築名稱,不吃靜態 label,見 CharacterStatusRule);DISMISSED
## 已被玩家解雇離隊;DEAD 已老死。祖譜/角色面板統一顯示這個狀態,取代舊版「年齡欄位
## 加註(已故)」的寫法。
enum CharacterStatus {ACTIVE, STATIONED, WORKING, DISMISSED, DEAD}


## 技能效果分類:ATTACK/DEBUFF 對敵方生效,BUFF/HEAL/DEFEND/SHIELD 對我方(含自己)生效,
## 由 Skill.resolve_targets() 依這個欄位決定候選名單要從 caster.enemies 還是
## caster.allies 挑,見 Spec.md。SHIELD(護盾)賦予目標一層獨立於 HP 之外的緩衝血量
## (BattleCharacter.shield_points),倍率格式比照 HEAL,但不直接回復 HP,傷害結算時
## 先扣護盾再扣 HP,見 CombatResolver.apply_damage()。
enum SkillType {ATTACK, BUFF, DEBUFF, HEAL, DEFEND, SHIELD}

## 技能造成的特殊效果標記,一個技能可以掛多個(Skill.mechanics),取代針對技能名稱的
## if/elif 特例判斷——BattleAi/SkillEffectLibrary/CombatResolver 一律只看這些旗標,
## 不看技能叫什麼名字。必中(無視閃避)因為只是單一 bool 開關,直接用 Skill.true_hit
## 欄位處理,不放進這個 enum。
## ARMOR_PIERCE(破防):傷害結算無視防禦方防禦加成。
## GUARANTEED_CRIT(必定暴擊):跳過暴擊判定,直接視為暴擊。
## COUNTER(反擊):受到攻擊後一定機率對攻擊者反擊,見 CombatResolver.judge_counter()。
## PERFECT_DODGE(完美迴避):獨立於一般迴避判定之外的第二層判定,見
## CombatResolver.judge_perfect_dodge()。
## TAUNT(嘲諷):命中後強制目標接下來優先攻擊自己,見 BattleCharacter.apply_taunt()。
## SEAL(封印):使目標接下來幾回合無法選用主動技能,見 BattleCharacter.apply_seal()。
## FEAR(恐懼):使目標接下來幾回合的行動骰選大幅偏向撤退/發呆,見
## BattleCharacter.apply_fear()。
## HEAL_DOWN(降治療):目標受到的治療效果打折扣。
## CLEANSE(異常解除):清除目標身上一項異常狀態,瞬間生效不算持續效果。
## REACTIVE_HEAL(反應治療):範圍內友軍受到攻擊時一定機率對其觸發小量治療,反應式判定,
## 不吃行動骰選。
## EXTRA_HIT_ON_ATTACK(追加一擊):普通攻擊命中後一定機率追加一次普通攻擊,只作用於
## 普通攻擊,不影響武器主動技。
## AREA_EXPAND_ON_ATTACK(範圍擴大):普通攻擊一定機率自動擴大成範圍攻擊,只作用於
## 普通攻擊,不影響武器主動技。
enum SkillMechanic {
	ARMOR_PIERCE, GUARANTEED_CRIT, COUNTER, PERFECT_DODGE, TAUNT, SEAL, FEAR,
	HEAL_DOWN, CLEANSE, REACTIVE_HEAL, EXTRA_HIT_ON_ATTACK, AREA_EXPAND_ON_ATTACK,
	## 以下六個是通用被動(18 條,見 SkillLibraryPassive)專用的機制,概念跟上面幾個
	## 一樣是「一個機制配一個共用判定函式」,不是各寫一個技能專屬效果:
	## DAMAGE_REDUCTION(永久或 HP 門檻內減傷,skill.skill_ratio=減傷比例、
	## skill.secondary_ratio=觸發門檻,0.0=無條件生效)、CHANCE_ARMOR_PIERCE/
	## CHANCE_GUARANTEED_CRIT(攻擊方普攻/技能都有 base_chance 機率觸發既有的破防/
	## 必定暴擊效果)、DODGE_COUNTER(防禦方成功閃避後,依 base_chance 機率立即反擊)、
	## KILL_MOMENTUM(攻擊方擊殺後,依 skill.skill_ratio/skill.duration_rounds 取得
	## 暫時的技能權重加成)、LIMITED_EXECUTE_COUNTER(防禦方 HP 低於 secondary_ratio 門檻
	## 時,整場戰鬥限一次觸發強力反擊,倍率吃 skill_ratio)。
	DAMAGE_REDUCTION, CHANCE_ARMOR_PIERCE, CHANCE_GUARANTEED_CRIT, DODGE_COUNTER,
	KILL_MOMENTUM, LIMITED_EXECUTE_COUNTER,
	## 全隊限時增益版的破防/必定暴擊(取代「全隊下一擊無視防禦/必中」這種需要暫時覆寫
	## 判定的不可行設計):duration_rounds 回合內,持有者的普攻/技能一律視為破防/必定
	## 暴擊,不是機率觸發——見 BattleCharacter.armor_pierce_rounds/guaranteed_crit_rounds,
	## 施放端(SkillEffectLibrary._apply_status_mechanics())當成純增益套用,不需要
	## judge_status_resist() 抵抗判定(不在 _NEGATIVE_MECHANICS 名單內)。1 回合的時限
	## 剛好對應「每個角色一回合只行動一次」,天然就是「下一擊」的效果,不需要另外做
	## 「用掉一次就消失」的一次性覆寫機制。
	GRANT_ARMOR_PIERCE, GRANT_GUARANTEED_CRIT,
}
enum ActionType {ATTACK, DAZE, ESCAPE, CONFUSE, SKILL}
enum Relations {SELF, ALLIES, NEUTRAL, HOSTILE, UNKNOWN}
enum TraitPolarity {POSITIVE, NEGATIVE, NEUTRAL}
## 戰鬥結果:依總大將(Party.leader/BattleCharacter.is_leader)死活判定,見 Battle.result
enum BattleResultType {SELF_WIN, ENEMY_WIN, DRAW}
## 戰鬥模式:AUTO 一次性模擬完直接重播(戰報模式,Battle.start());REALTIME 逐回合跑
## (Battle.start_realtime()/step_round()),回合間開放玩家手動施放奧義(見
## System/ultimate/)。兩種模式共用 Battle 的核心迴圈(round_progress() 等),差別只在
## 外層怎麼驅動,見 Battle 類別註解。
enum BattleMode {AUTO, REALTIME}
## 技能範圍效果的形狀:SINGLE 只打中鎖定的那個目標;RADIUS 以命中目標為中心的菱形範圍
## (曼哈頓距離 ≤ area_size-1);LINE 從目標往施法者的反方向延伸 area_size 格「貫穿」;
## SQUARE 以命中目標為中心的正方形範圍(切比雪夫距離 ≤ area_size-1);ALL_ALLIES 無視
## 距離,直接命中施法者本人+所有存活隊友(全隊技能用,例如 D. 大將之風);ALL_ENEMIES
## 是 ALL_ALLIES 的敵方版本,無視距離直接命中所有存活敵人(大將減益技用)。
enum AreaShape {SINGLE, RADIUS, LINE, SQUARE, ALL_ALLIES, ALL_ENEMIES}
## 戰報事件型別,對應 System/battle/events/ 底下的 BattleEvent 子類別,
## 見 Spec.md 一、戰報事件合約。
enum BattleEventType {
	BATTLE_START, ROUND_START, ROUND_END,
	MOVE, DAZE, ATTACK, SKILL,
	DODGE, DAMAGE, HEAL, SHIELD,
	STAT_EFFECT, STAT_EFFECT_EXPIRED,
	STATUS_MECHANIC,
	GUARD, DEFEATED, BATTLE_END,
	ULTIMATE_RESOLVE,
}
## 對話場景固定二人站位(左/右),見 System/dialogue/、Scenes/Dialogue/dialogue_box.gd——
## 目前畫面版型只設計左右各一位發言角色,不支援多人對話。NARRATOR 是旁白:不佔任何一側
## 站位,講話時左右兩側都不是「正在講話的那側」,兩邊頭像自然一起蓋灰色遮罩(變暗),
## 對話仍照常一句句往下播,不是獨立流程。
enum DialogueSide {LEFT, RIGHT, NARRATOR}
## 血統六大國家,對應血統代表色紅/白/黃/綠/藍/青,見 System/bloodline/
enum BloodlineNation {LION, EAGLE, LEOPARD, BEAR, DRAGON, DEER}
## 血統階級:平民血統/高階血統,同一國家內兩者是分開計量的獨立欄位
enum TerrainType {PLAINS, MOUNTAINS, PLATEAU, FOREST, DESERT, ICEFIELD}
# 對應六種國家所處的六種地理環境,見 Spec.md 六、血統國家與地理環境對照表,以及
# bloodline_nation_terrain() 的換算。
enum BloodlineRank {COMMON, NOBLE}
## 角色性別。目前 CharacterController 隨機產生的角色池只有男性姓名庫(MALE_CHARACTER_NAMES),
## 一律指派 MALE,先開這個欄位是為了女性角色(玩家間聯姻等企劃內容)日後擴充鋪路。
enum Gender {MALE, FEMALE}
## 告白畫面模式,見 Scenes/Marriage/marriage_proposal.gd:INCOMING 是「對方主動來告白」
## (雙方角色已固定,畫面只用來看資訊+決定接受/婉拒),OUTGOING 是「玩家選人去告白」
## (對方固定,玩家從角色池挑我方人選)。
enum ProposalMode {INCOMING, OUTGOING}

## 任務類型,見 System/quest/。DELIVERY(交貨委託)完成方式是玩家在任務列表手動繳交
## 指定資源(見 QuestStore.complete_delivery_quest());COURIER(送信委託)完成方式是
## 玩家移動到 Quest.destination_nation 對應的城鎮地點選單畫面(見
## Scenes/MapLocation/map_location.gd 呼叫 QuestStore.notify_courier_arrived())。之後
## 新增任務種類時在這裡擴充,QuestLibrary 的文案/生成分支要跟著加。
enum QuestType {BANDIT_SUBJUGATION, DELIVERY, COURIER}
## 任務進度狀態:IN_PROGRESS 進行中,COMPLETED 已達成條件並發過獎勵,EXPIRED 逾期未完成
## (見 QuestStore._on_day_passed())。COMPLETED/EXPIRED 都會永久留在 QuestStore.quests
## 清單裡當結果紀錄,任務列表(Scenes/QuestList/quest_list.gd)只給 IN_PROGRESS 顯示
## 「放棄」按鈕(QuestStore.abandon_quest()),COMPLETED/EXPIRED 沒有任何按鈕、玩家沒有
## 主動清除的管道。
enum QuestStatus {IN_PROGRESS, COMPLETED, EXPIRED}
## 任務分類,對應 Scenes/QuestList/quest_list.gd 左側邊欄的三個分頁——跟 QuestType
## (任務實際內容,例如討伐周邊強盜)是兩個獨立欄位,同一個 QuestType 理論上可能被歸進
## 不同分類。目前只有 TownTavernEvent 酒館老闆「詢問委託」接的三種任務是 COMMISSION
## (委託任務),MAIN(主線任務)/SIDE(支線任務)先開分頁佔位,還沒有對應的任務生成來源。
enum QuestCategory {MAIN, SIDE, COMMISSION}

## 國與國之間的邦交狀態,見 System/nation/nation_relation.gd。目前沒有任何機制會
## 改變邦交,一律回傳 PEACE,先開這個欄位讓 Scenes/NationRelations 有型別可用。
enum NationWarStatus {PEACE, WAR}

## 六大素質 UI 顯示用中文標籤,順序對應 PotentialType enum
const POTENTIAL_TYPE_LABELS: Array[String] = ["力量", "體質", "敏捷", "靈巧", "智慧", "信仰"]

## 評級 UI 顯示用標籤,順序對應 RankType enum
const RANK_TYPE_LABELS: Array[String] = ["F", "E", "D", "C", "B", "A", "S", "SS", "SSS"]

## 武器 UI 顯示用中文標籤,順序對應 WeaponType enum
const WEAPON_TYPE_LABELS: Array[String] = ["劍", "弓", "盾", "匕首", "法杖", "捕夢網"]

## 角色清單排序欄位 UI 顯示用中文標籤,順序對應 CharacterSortKey enum
const CHARACTER_SORT_KEY_LABELS: Array[String] = ["等級", "總數值", "格子數", "力量", "體質", "敏捷", "靈巧", "智慧", "信仰"]

## 大地圖地點 UI 顯示用中文標籤,順序對應 MapObjectType enum
const MAP_OBJECT_TYPE_LABELS: Array[String] = ["城鎮", "根據地", "城堡"]

## 根據地建築類型,見 System/base/building/building_library.gd 與
## 遊戲企劃設定總整理.md 六十八節。前五種(城鎮中心~兵營)是非生產類建築,功能尚未
## 實作;後十二種是生產類建築,每種對應六大素質之一。其中 6 種(採石場/採礦場/黑市/
## 抄書院/科學研究所/禁忌祭壇)月結算會額外消耗固定資源才能產出(見 Building.fixed_recipe),
## 工匠坊則是玩家自選三種配方之一(見 WorkshopRecipeLibrary),其餘 5 種不消耗任何資源。
enum BuildingType {
	STRONGHOLD, RESIDENTIAL, CLINIC, WAREHOUSE, BARRACKS,
	LUMBER_MILL, QUARRY, FARM, MINE, CARAVAN, BLACK_MARKET,
	HUNTING_GROUND, WORKSHOP, SCRIPTORIUM, RESEARCH_INSTITUTE,
	ALTAR, FORBIDDEN_ALTAR,
}

## 根據地建築 UI 顯示用中文標籤,順序對應 BuildingType enum
const BUILDING_TYPE_LABELS: Array[String] = [
	"城鎮中心", "住宅區", "醫療所", "倉庫", "兵營",
	"伐木場", "採石場", "農田", "採礦場", "商隊站", "黑市",
	"狩獵場", "工匠坊", "抄書院", "科學研究所",
	"祭壇", "禁忌祭壇",
]

## 根據地資源類型,見 System/base/base_production.gd / Scripts/Autoload/base_resource_store.gd
enum ResourceType {
	WOOD, STONE, FOOD, ORE, GOLD, CONTRABAND, FUR, TOOL,
	BOOK, RESEARCH, FAITH, CURSE,
}

## 根據地資源 UI 顯示用中文標籤,順序對應 ResourceType enum
const RESOURCE_STRING_LABELS: Array[String] = [
	"木材", "石材", "糧食", "鐵礦", "金錢", "贓物", "毛皮", "工具",
	"書本", "科研", "信仰", "詛咒",
]

## 血統國家 UI 顯示用中文標籤,順序對應 BloodlineNation enum
const BLOODLINE_NATION_LABELS: Array[String] = ["獅", "鷹", "豹", "熊", "龍", "鹿"]

## 血統階級 UI 顯示用中文標籤,順序對應 BloodlineRank enum,跟國家標籤相接組成
## 「獅血」「獅高血」這種完整血統名稱,見 bloodline_full_label()
const BLOODLINE_RANK_LABELS: Array[String] = ["血", "高血"]

## 性別 UI 顯示用符號,順序對應 Gender enum
const GENDER_SYMBOLS: Array[String] = ["男", "女"]

## 任務類型 UI 顯示用中文標籤,順序對應 QuestType enum
const QUEST_TYPE_LABELS: Array[String] = ["討伐委託", "交貨委託", "送信委託"]

## 任務進度狀態 UI 顯示用中文標籤,順序對應 QuestStatus enum
const QUEST_STATUS_LABELS: Array[String] = ["進行中", "已完成", "已過期"]

## 任務分類 UI 顯示用中文標籤,順序對應 QuestCategory enum
const QUEST_CATEGORY_LABELS: Array[String] = ["主線任務", "支線任務", "委託任務"]

## 邦交狀態 UI 顯示用中文標籤,順序對應 NationWarStatus enum
const NATION_WAR_STATUS_LABELS: Array[String] = ["停戰中", "交戰中"]

## 以下四個 label 靜態函式包一層陣列索引,畫面端(Scenes/)一律呼叫這幾個函式取標籤,
## 不要直接寫 GameEnums.XXX_LABELS[type]——直接索引在 enum 之後新增/調整順序時
## 不會有任何編譯期或執行期警告,悄悄對應錯標籤;呼叫函式至少能在這裡集中防呆。
static func potential_label(potential_type: int) -> String:
	return POTENTIAL_TYPE_LABELS[potential_type]

static func rank_label(rank_type: int) -> String:
	return RANK_TYPE_LABELS[rank_type]

static func weapon_label(weapon_type: int) -> String:
	return WEAPON_TYPE_LABELS[weapon_type]

static func character_sort_key_label(sort_key: int) -> String:
	return CHARACTER_SORT_KEY_LABELS[sort_key]

static func map_object_type_label(map_object_type: int) -> String:
	return MAP_OBJECT_TYPE_LABELS[map_object_type]

static func quest_type_label(quest_type: int) -> String:
	return QUEST_TYPE_LABELS[quest_type]

static func quest_status_label(quest_status: int) -> String:
	return QUEST_STATUS_LABELS[quest_status]

static func quest_category_label(quest_category: int) -> String:
	return QUEST_CATEGORY_LABELS[quest_category]

static func nation_war_status_label(war_status: int) -> String:
	return NATION_WAR_STATUS_LABELS[war_status]

static func building_type_label(building_type: int) -> String:
	return BUILDING_TYPE_LABELS[building_type]

static func resource_string_label(resource_type: int) -> String:
	return RESOURCE_STRING_LABELS[resource_type]

## 資源圖示路徑(見 Images/ResourceType/),檔名對應 ResourceType enum 成員名稱,同
## weapon_icon_path()/base_building_background_path() 的慣例——取代舊版
## RESOURCE_TYPE_LABELS 那組 emoji,畫面一律改用 TextureRect 載入這裡回傳的路徑。
static func resource_type_icon_path(resource_type: int) -> String:
	return "res://Images/ResourceType/%s.png" % ResourceType.keys()[resource_type]

static func bloodline_nation_label(nation: int) -> String:
	return BLOODLINE_NATION_LABELS[nation]

static func bloodline_rank_label(rank: int) -> String:
	return BLOODLINE_RANK_LABELS[rank]

static func gender_symbol(gender: int) -> String:
	return GENDER_SYMBOLS[gender]

## 組合國家+階級的完整血統名稱,例如「獅血」「獅高血」,UI 一律呼叫這個,不要自己串字串
static func bloodline_full_label(nation: int, rank: int) -> String:
	return bloodline_nation_label(nation) + bloodline_rank_label(rank)

## BATTLE_COST 方塊外框色,依武器分色一眼辨識:大劍紅、弓箭手白、盾牌綠、
## 匕首黃、法杖藍、捕夢網青,順序對應 WeaponType enum
const WEAPON_BORDER_COLORS: Array[Color] = [
	Color(0.85, 0.2, 0.2, 1), # 大劍:紅
	Color(0.92, 0.92, 0.92, 1), # 弓箭手:白
	Color(0.35, 0.85, 0.35, 1), # 盾牌:綠
	Color(1.0, 0.85, 0.15, 1), # 匕首:黃
	Color(0.35, 0.55, 1.0, 1), # 法杖:藍
	Color(0.3, 0.9, 0.9, 1), # 捕夢網:青
]

static func weapon_border_color(weapon_type: int) -> Color:
	return WEAPON_BORDER_COLORS[weapon_type]

## 武器圖示路徑(見 Images/Weapon/),檔名對應 WeaponType enum 的成員名稱,
## 順序對應 WeaponType enum
const WEAPON_ICON_PATHS: Array[String] = [
	"res://Images/Weapon/SWORD.svg",
	"res://Images/Weapon/BOW.svg",
	"res://Images/Weapon/SHIELD.svg",
	"res://Images/Weapon/DAGGER.svg",
	"res://Images/Weapon/STAFF.svg",
	"res://Images/Weapon/DREAMCATCHER.svg",
]

static func weapon_icon_path(weapon_type: int) -> String:
	return WEAPON_ICON_PATHS[weapon_type]

## 六大素質代表色(素質增益/減益箭頭、雷達圖等畫面共用同一份配色表),
## 順序對應 PotentialType enum
const POTENTIAL_TYPE_COLORS: Array[Color] = [
	Color(0.85, 0.2, 0.2), # 紅:力量
	Color(0.35, 0.85, 0.35), # 綠:體質
	Color(1.0, 0.85, 0.15), # 黃:敏捷
	Color(0.92, 0.92, 0.92), # 白:靈巧
	Color(0.35, 0.55, 1.0), # 藍:智慧
	Color(0.3, 0.9, 0.9), # 青:信仰
]

static func potential_color(potential_type: int) -> Color:
	return POTENTIAL_TYPE_COLORS[potential_type]

## 場上/頭像列的特殊狀態文字標籤,只涵蓋「有持續回合、需要玩家看得到目前中了什麼」的
## 機制(恐懼/封印/嘲諷/降治療/全隊限時破防&必定暴擊);其餘機制(反擊/完美迴避/反應治療/
## 追加一擊/範圍擴大/減傷/機率破防&暴擊/擊殺技能權重/限定反擊/異常解除)是永久被動或瞬間
## 生效,沒有「目前正中著」的持續狀態可以顯示,回傳空字串。
static func mechanic_status_label(mechanic: SkillMechanic) -> String:
	match mechanic:
		SkillMechanic.FEAR:
			return "恐懼"
		SkillMechanic.SEAL:
			return "封印"
		SkillMechanic.TAUNT:
			return "嘲諷"
		SkillMechanic.HEAL_DOWN:
			return "降治療"
		SkillMechanic.GRANT_ARMOR_PIERCE:
			return "破防"
		SkillMechanic.GRANT_GUARANTEED_CRIT:
			return "必暴"
		_:
			return ""

## 血統國家代表色(計量槽顏色),順序對應 BloodlineNation enum:獅紅/鷹白/豹黃/熊綠/龍藍/鹿青
const BLOODLINE_NATION_COLORS: Array[Color] = [
	Color(0.85, 0.2, 0.2), # 紅:獅
	Color(0.92, 0.92, 0.92), # 白:鷹
	Color(1.0, 0.85, 0.15), # 黃:豹
	Color(0.35, 0.85, 0.35), # 綠:熊
	Color(0.35, 0.55, 1.0), # 藍:龍
	Color(0.3, 0.9, 0.9), # 青:鹿
]

static func bloodline_nation_color(nation: int) -> Color:
	return BLOODLINE_NATION_COLORS[nation]

## 血統國家所屬地形,順序對應 BloodlineNation enum:獅→平原/鷹→森林/豹→沙漠/熊→山岳/
## 龍→冰原/鹿→高原,對照表見 Spec.md 六、血統國家與地理環境對照表。
const BLOODLINE_NATION_TERRAINS: Array[TerrainType] = [
	TerrainType.PLAINS, TerrainType.FOREST, TerrainType.DESERT,
	TerrainType.MOUNTAINS, TerrainType.ICEFIELD, TerrainType.PLATEAU,
]

static func bloodline_nation_terrain(nation: int) -> int:
	return BLOODLINE_NATION_TERRAINS[nation]

## 城鎮外觀對話背景圖(Images/Dialogue/Map/Town/town_<TERRAIN>.png)——檔名直接對應
## TerrainType enum 成員名稱,不另外維護一份路徑陣列(下面 base_building_background_path()
## 同理),見 System/map/map_object.gd 的 MapObject.terrain_type()。同時也是
## Scenes/MapLocation/map_location.gd 進到 TOWN 地點選單時的整頁背景圖。
static func town_background_path(terrain_type: int) -> String:
	return "res://Images/Dialogue/Map/Town/town_%s.png" % TerrainType.keys()[terrain_type]

static func terrain_background_path(terrain_type: int) -> String:
	return "res://Images/Dialogue/Map/Terrain/%s.png" % TerrainType.keys()[terrain_type]

## 大地圖城鎮圖示(Images/Map/MapObject/Town/),見 Scenes/MapObject/Town/town.gd。
## 檔名沿用美術原始命名(DESSERT 是既有拼字,不是 DESERT 的筆誤修正),所以不能像
## town_background_path() 那樣直接用 TerrainType.keys() 拼路徑,改用固定對照表。
const TOWN_MAP_ICON_FILENAMES: Array[String] = [
	"TOWN_PLAINS.png", "TOWN_MOUNTAINS.png", "TOWN_PLATEAU.png",
	"TOWN_FOREST.png", "TOWN_DESSERT.png", "TOWN_ICEFIELD.png",
]

static func town_map_icon_path(terrain_type: int) -> String:
	return "res://Images/Map/MapObject/Town/%s" % TOWN_MAP_ICON_FILENAMES[terrain_type]

## 大地圖城堡圖示(Images/Map/MapObject/Castle/),見 Scenes/MapObject/Castle/castle.gd。
## 同上不能用 TerrainType.keys() 拼路徑,原因同 TOWN_MAP_ICON_FILENAMES。
const CASTLE_MAP_ICON_FILENAMES: Array[String] = [
	"CASTLE_PLAINS.png", "CASTLE_MOUNTAINS.png", "CASTLE_PLATEAU.png",
	"CASTLE_FOREST.png", "CASTLE_DESSERT.png", "CASTLE_ICEFIELD.png",
]

static func castle_map_icon_path(terrain_type: int) -> String:
	return "res://Images/Map/MapObject/Castle/%s" % CASTLE_MAP_ICON_FILENAMES[terrain_type]

## 根據地內部共用對話背景圖(不分地形),見 System/event/base/base_leave_event.gd
## 的離開過場。
const CASTLE_INTERIOR_BACKGROUND_PATH := "res://Images/Dialogue/Castle/castle_interior.png"

## 根據地建築對話背景圖(Images/Dialogue/Base/Building/<BUILDING_TYPE>.png)——檔名對應
## BuildingType enum 成員名稱,見 System/event/base/base_building_event.gd。
static func base_building_background_path(building_type: int) -> String:
	return "res://Images/Dialogue/Base/Building/%s.png" % BuildingType.keys()[building_type]

## Scenes/MapLocation/map_location.gd 進到 BASE 地點選單時的整頁背景圖,玩家還沒有
## 可選的自身國家血統,不像 TOWN 分地形,先固定這一張。
const BASE_LOCATION_BACKGROUND_PATH := "res://Images/Dialogue/Map/Base.png"

## 大地圖城鎮村民聊天(TownChatEvent)固定用的對話背景圖,不分地形(聊天發生在城裡
## 隨處可見的住宅區,跟 TOWN_LABEL/城門/酒館等特定場景無關)。
const TOWN_RESIDENTIAL_BACKGROUND_PATH := "res://Images/Dialogue/Town/town_residential.png"

## 城鎮中心聯姻流程(見 System/event/base/base_marriage_event.gd)候選人回信場景背景,
## 依候選人血統高低二選一:高血(Bloodline.get_total_noble_percentage() >= 50)站在
## 王座廳、平民站在住宅區(跟 TOWN_RESIDENTIAL_BACKGROUND_PATH 共用同一張圖)。
const TOWN_THRONE_ROOM_BACKGROUND_PATH := "res://Images/Dialogue/Town/town_throne_room.png"

## 隊長標記圖示:疊在頭像/小人物右上角的小旗子,取代舊版變色遮罩。
## BattleUnitVisual(戰場角色)、BattlePartyRoster(頭像列)與 BattleCostView
## (PartyEdit/CharacterPanel 的 battle_cost 縮圖)共用同一張圖,標記邏輯要一致。
const LEADER_FLAG_ICON_PATH := "res://Images/Icon/FLAG.png"

## 素質清單轉成頓號分隔的標籤字串,例如 stat_effect 事件的「力量、敏捷」——
## 戰報事件的 detail 組字與 Scenes/battle.gd 的戰報 UI 都共用這個,
## 不要各自各寫一份 for 迴圈。
static func format_potential_type_list(potential_types: Array) -> String:
	var labels: Array[String] = []
	for potential_type in potential_types:
		labels.append(potential_label(potential_type))
	return "、".join(labels)

## 基本攻擊距離(曼哈頓格數):近戰(劍/盾/匕首)1 格、遠程(弓/法杖/捕夢網)2 格,
## 順序對應 WeaponType enum
const WEAPON_BASIC_ATTACK_RANGE: Array[int] = [1, 2, 1, 1, 2, 2]

## 是否為魔法攻擊(法杖/捕夢網):魔法攻擊無視閃避,一定命中,順序對應 WeaponType enum
const WEAPON_IS_MAGIC: Array[bool] = [false, false, false, false, true, true]

const CHARACTER_LAST_NAMES: Array[String] = [
	"阿什福德", "艾爾頓", "艾文斯", "巴洛", "貝爾蒙", "布萊克伍德", "布萊恩特", "布倫特",
	"布里奇斯", "卡特爾", "克萊爾", "克雷頓", "克羅夫特", "達文波特", "德雷克", "德文",
	"埃弗里特", "費爾德", "費雪", "福克斯", "福特", "加洛韋", "格雷森", "格里芬",
	"哈德森", "哈特", "霍爾登", "霍金斯", "亨特", "傑佛遜", "肯特", "蘭開斯特",
	"蘭頓", "勞倫斯", "洛克伍德", "馬洛", "梅森", "米爾頓", "蒙哥馬利", "摩根",
	"諾克斯", "奧斯汀", "帕克", "佩頓", "普雷斯頓", "雷德", "雷諾茲", "里德",
	"羅森", "羅斯", "桑德斯", "謝爾頓", "斯特林", "泰勒", "湯普森", "沃克",
	"沃倫", "韋斯特", "威爾斯", "威爾遜", "伍德", "懷特", "艾斯頓", "阿什頓",
	"貝克特", "伯恩斯", "布萊頓", "卡爾頓", "卡文迪許", "克雷斯", "德文郡", "埃利斯",
	"埃弗雷特", "弗林特", "格蘭特", "格雷", "哈羅德", "霍華德", "蘭伯特", "洛克",
	"梅里克", "蒙羅", "奧爾森", "佩里", "昆恩", "羅蘭", "斯科特", "斯通",
	"薩默斯", "特納", "瓦倫", "韋伯", "威斯特", "溫特斯", "伍德羅", "約克",
]

const MALE_CHARACTER_NAMES: Array[String] = [
	"約翰", "保羅", "喬治", "亞歷克斯", "馬克斯", "大衛", "丹尼爾", "馬克", "約瑟夫", "派屈克",
	"安德魯", "安東尼", "理查德", "查爾斯", "托馬斯", "威廉", "萊恩", "雅各布", "凱文", "邁克爾",
	"史蒂文", "彌敦", "愛德華", "布蘭登", "史考特", "班傑明", "埃里克", "約書亞", "菲利普", "布賴恩",
	"賈森", "格雷戈里", "撒迦", "亞瑟", "亞當", "亞倫", "亞伯特", "阿德里安", "亞歷山大", "阿爾弗雷德",
	"奧利弗", "奧斯卡", "奧斯汀", "奧古斯都", "巴納比", "巴塞洛繆", "貝內迪克特", "伯納德", "布萊恩", "布魯斯",
	"卡爾", "卡斯帕", "塞德里克", "克里斯多福", "克勞德", "康拉德", "康斯坦丁", "達米安", "達里安", "德米特里",
	"多米尼克", "埃德蒙", "埃德加", "埃利亞斯", "埃利奧特", "埃米爾", "費利克斯", "費迪南", "弗雷德里克", "加布里埃爾",
	"加雷斯", "加文", "戈弗雷", "戈登", "哈羅德", "亨利", "休", "伊恩", "伊薩克", "傑拉德",
	"傑弗里", "傑羅姆", "萊昂納德", "里奧", "路易斯", "盧卡斯", "盧西恩", "馬丁", "馬修", "梅爾文",
	"尼古拉斯", "諾蘭", "奧蘭多", "奧斯卡", "佩爾西瓦爾", "昆汀", "雷蒙德", "羅伯特", "羅蘭", "魯道夫",
	"塞巴斯蒂安", "西奧多", "提摩西", "特里斯坦", "維克多", "文森特", "沃爾特", "扎卡里", "亞瑟", "蘭斯洛特",
]

const FEMALE_CHARACTER_NAMES: Array[String] = [
	"艾瑪", "奧莉維亞", "艾娃", "伊莎貝拉", "索菲亞", "米婭", "夏洛特", "艾蜜莉", "艾比蓋兒", "哈珀",
	"艾蜜莉亞", "伊莉莎白", "艾弗里", "艾拉", "艾麗", "奧羅拉", "維多利亞", "卡蜜拉", "莉莉", "格蕾絲",
	"克洛伊", "佩內洛普", "蕾拉", "萊莉", "諾拉", "莉莉安", "伊蓮娜", "艾琳", "安娜", "艾莉絲",
	"克萊兒", "薇薇安", "露西", "艾莉安娜", "莎拉", "伊芙", "茱莉亞", "蘿拉", "蘇菲", "艾蓮娜",
	"凱瑟琳", "瑪格麗特", "伊莎貝爾", "羅絲", "黛安娜", "塞西莉亞", "克拉拉", "貝雅特麗絲", "阿梅莉亞", "海倫",
	"露易絲", "瑪麗安", "珍妮佛", "麗貝卡", "娜塔莉", "蕾切爾", "維奧拉", "奧菲莉亞", "安吉拉", "史黛拉",
	"塞拉菲娜", "羅莎琳", "伊芙琳", "阿德萊德", "安娜貝爾", "瑪蒂爾達", "伊迪絲", "埃莉諾", "格溫多琳", "羅莎莉",
	"菲奧娜", "梅芙", "布麗姬", "希爾達", "伊莉絲", "阿斯特麗德", "西爾維亞", "薇拉", "奧黛麗", "埃絲特",
	"弗洛拉", "露娜", "塞琳娜", "卡珊德拉", "塔莉亞", "阿莉亞", "米拉", "妮娜", "艾薇", "莉安娜",
	"瑟琳", "阿莉莎", "梅麗莎", "珍妮", "安妮", "瑪莎", "艾達", "莉迪亞", "薇奧拉", "梅拉妮",
	"卡洛琳", "伊莎", "索菲", "瑪麗", "朱莉", "蕾妮", "薇若妮卡", "伊蓮娜", "艾琳娜", "艾芙琳",
]
