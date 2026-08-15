class_name GameEnums
extends RefCounted

enum RankType {E, D, C, B, A, S, SS, SSS}
enum PotentialType {STRENGTH, VITALITY, AGILITY, DEXTERITY, INTELLIGENCE, MENTALITY}
enum WeaponType {SWORD, BOW, SHIELD, DAGGER, STAFF, DREAMCATCHER}
## Skill.bind_weapon 專用的「未綁定特定武器」標記(被動/隊長技能等任何武器都能用),
## 故意不塞進 WeaponType enum——角色一定持有真實武器,WeaponType 只代表可持有的
## 武器種類,不該混入這種非武器的旗標值。
const NO_WEAPON_BINDING := -1
## 角色清單排序欄位(PartyEdit 候補清單/未來其他角色清單共用,見 HeroSortFilter),
## 前三項是衍生值,後六項對應 PotentialType 六大素質
enum HeroSortKey {LEVEL, TOTAL_POTENTIAL, CELL_COUNT, STRENGTH, VITALITY, AGILITY, DEXTERITY, INTELLIGENCE, MENTALITY}
## 大地圖上的地點類型,見 System/Map/MapObjectData.gd
enum MapObjectType {CASTLE}
## 技能效果分類:ATTACK/DEBUFF 對敵方生效,BUFF/HEAL/DEFEND 對我方(含自己)生效,
## 由 Skill.resolve_targets() 依這個欄位決定候選名單要從 caster.enemies 還是
## caster.allies 挑,見 Spec.md。
enum SkillType {ATTACK, BUFF, DEBUFF, HEAL, DEFEND}
enum ActionType {ATTACK, DAZE, ESCAPE, CONFUSE, SKILL}
enum Relations {SELF, ALLIES, NEUTRAL, HOSTILE, UNKNOWN}
enum TraitPolarity {POSITIVE, NEGATIVE, NEUTRAL}
## 戰鬥結果:依總大將(Party.leader/BattleHero.is_leader)死活判定,見 Battle.result
enum BattleResultType {SELF_WIN, ENEMY_WIN, DRAW}
## 戰鬥模式:AUTO 一次性模擬完直接重播(戰報模式,Battle.start());REALTIME 逐回合跑
## (Battle.start_realtime()/step_round()),回合間開放玩家手動施放奧義(見
## System/ultimate/)。兩種模式共用 Battle 的核心迴圈(round_progress() 等),差別只在
## 外層怎麼驅動,見 Battle 類別註解。
enum BattleMode {AUTO, REALTIME}
## 技能範圍效果的形狀:SINGLE 只打中鎖定的那個目標;RADIUS 以命中目標為中心的菱形範圍
## (曼哈頓距離 ≤ area_size-1);LINE 從目標往施法者的反方向延伸 area_size 格「貫穿」;
## SQUARE 以命中目標為中心的正方形範圍(切比雪夫距離 ≤ area_size-1);ALL_ALLIES 無視
## 距離,直接命中施法者本人+所有存活隊友(全隊技能用,例如 D. 大將之風)。
enum AreaShape {SINGLE, RADIUS, LINE, SQUARE, ALL_ALLIES}
## 戰報事件型別,對應 System/battle/events/ 底下的 BattleEvent 子類別,
## 見 Spec.md 一、戰報事件合約。
enum BattleEventType {
	BATTLE_START, ROUND_START, ROUND_END,
	MOVE, DAZE, ATTACK, SKILL,
	DODGE, DAMAGE, HEAL,
	STAT_EFFECT, STAT_EFFECT_EXPIRED,
	GUARD, DEFEATED, BATTLE_END,
	ULTIMATE_RESOLVE,
}
## 對話場景固定二人站位(左/右),見 System/dialogue/、Scenes/Dialogue/dialogue_box.gd——
## 目前畫面版型只設計左右各一位發言角色,不支援多人對話
enum DialogueSide {LEFT, RIGHT}

## 六大素質 UI 顯示用中文標籤,順序對應 PotentialType enum
const POTENTIAL_TYPE_LABELS: Array[String] = ["力量", "體質", "敏捷", "靈巧", "智慧", "信仰"]

## 評級 UI 顯示用標籤,順序對應 RankType enum
const RANK_TYPE_LABELS: Array[String] = ["E", "D", "C", "B", "A", "S", "SS", "SSS"]

## 武器 UI 顯示用中文標籤,順序對應 WeaponType enum
const WEAPON_TYPE_LABELS: Array[String] = ["劍", "弓", "盾", "匕首", "法杖", "捕夢網"]

## 角色清單排序欄位 UI 顯示用中文標籤,順序對應 HeroSortKey enum
const HERO_SORT_KEY_LABELS: Array[String] = ["等級", "總數值", "格子數", "力量", "體質", "敏捷", "靈巧", "智慧", "信仰"]

## 大地圖地點 UI 顯示用中文標籤,順序對應 MapObjectType enum
const MAP_OBJECT_TYPE_LABELS: Array[String] = ["城堡"]

## 以下四個 label 靜態函式包一層陣列索引,畫面端(Scenes/)一律呼叫這幾個函式取標籤,
## 不要直接寫 GameEnums.XXX_LABELS[type]——直接索引在 enum 之後新增/調整順序時
## 不會有任何編譯期或執行期警告,悄悄對應錯標籤;呼叫函式至少能在這裡集中防呆。
static func potential_label(potential_type: int) -> String:
	return POTENTIAL_TYPE_LABELS[potential_type]

static func rank_label(rank_type: int) -> String:
	return RANK_TYPE_LABELS[rank_type]

static func weapon_label(weapon_type: int) -> String:
	return WEAPON_TYPE_LABELS[weapon_type]

static func hero_sort_key_label(sort_key: int) -> String:
	return HERO_SORT_KEY_LABELS[sort_key]

static func map_object_type_label(map_object_type: int) -> String:
	return MAP_OBJECT_TYPE_LABELS[map_object_type]

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

## 隊長標記色:小人物本身變色遮罩(modulate),不額外畫圈/光暈——我方隊長淡黃、
## 敵方隊長深紅。BattleUnitVisual(戰場角色)與 BattleCostView(PartyEdit/
## CharacterPanel 的 battle_cost 縮圖)共用同一組色,標記邏輯要一致。
const LEADER_SELF_TINT := Color(1.0, 0.95, 0.55)
const LEADER_ENEMY_TINT := Color(0.55, 0.05, 0.05)

static func leader_tint(is_enemy: bool) -> Color:
	return LEADER_ENEMY_TINT if is_enemy else LEADER_SELF_TINT

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

const MALE_HERO_NAMES: Array[String] = [
	"約翰", "保羅", "喬治", "亞歷克斯", "馬克斯", "大衛", "丹尼爾", "馬克", "約瑟夫", "派屈克",
	"安德魯", "安東尼", "理查德", "查爾斯", "托馬斯", "威廉", "萊恩", "雅各布", "凱文", "邁克爾",
	"史蒂文", "彌敦", "愛德華", "布蘭登", "史考特", "班傑明", "埃里克", "約書亞", "菲利普", "布賴恩",
	"賈森", "格雷戈里", "撒迦",
]

const MALE_HERO_LAST_NAMES: Array[String] = [
	"貝克", "史密斯", "約翰遜", "威廉斯", "瓊斯", "布朗", "戴維斯", "米勒", "威爾遜", "摩爾",
	"泰勒", "安德森", "托馬斯", "傑克遜", "懷特", "哈里斯", "馬丁", "湯普森", "加西亞", "馬丁内斯",
	"羅賓遜", "克拉克", "羅德里格斯", "路易斯", "李", "沃克", "霍爾", "艾倫", "楊", "埃爾南德斯",
	"金", "賴特", "洛佩茲", "希爾", "斯科特", "格林", "亞當斯", "納爾遜", "卡特", "米歇爾",
	"佩雷斯", "羅伯茨", "特納", "菲利普斯", "坎貝爾", "帕克", "埃文斯", "愛德華茲", "柯林斯", "斯圖爾特",
	"桑切斯", "莫里斯", "羅傑斯", "里德", "庫克", "摩根", "貝爾", "墨菲", "貝利", "里維拉",
	"庫珀", "理查森", "考克斯", "霍華德", "華爾德", "托雷斯", "彼得森", "格雷", "拉米雷斯", "詹姆斯",
	"沃特森", "布魯克斯", "凱利", "桑德斯", "普萊斯", "班奈特", "伍德", "巴恩斯", "羅斯", "亨德森",
	"科爾曼", "傑金斯", "佩里", "鮑威爾", "亞歷山大", "羅素", "格里芬", "迪亞斯", "海斯", "邁爾斯",
	"福斯特", "哈密爾頓", "格雷厄姆", "沙利文", "華勒斯", "傅斯特", "哥倫茲", "布萊恩", "迪亞茲", "喬丹",
	"歐文斯", "雷諾斯", "費舍爾", "埃利斯", "加納斯",
]
