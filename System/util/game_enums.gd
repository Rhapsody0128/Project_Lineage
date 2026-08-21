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
enum MapObjectType {TOWN, BASE}


## 技能效果分類:ATTACK/DEBUFF 對敵方生效,BUFF/HEAL/DEFEND 對我方(含自己)生效,
## 由 Skill.resolve_targets() 依這個欄位決定候選名單要從 caster.enemies 還是
## caster.allies 挑,見 Spec.md。
enum SkillType {ATTACK, BUFF, DEBUFF, HEAL, DEFEND}
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
## 目前畫面版型只設計左右各一位發言角色,不支援多人對話。NARRATOR 是旁白:不佔任何一側
## 站位,講話時左右兩側都不是「正在講話的那側」,兩邊頭像自然一起蓋灰色遮罩(變暗),
## 對話仍照常一句句往下播,不是獨立流程。
enum DialogueSide {LEFT, RIGHT, NARRATOR}
## 血統六大國家,對應血統代表色紅/白/黃/綠/藍/青,見 System/bloodline/
enum BloodlineNation {LION, EAGLE, LEOPARD, BEAR, DRAGON, DEER}
## 血統階級:平民血統/高階血統,同一國家內兩者是分開計量的獨立欄位
enum TerrainType {PLAINS, MOUNTAINS, PLATEAU, FOREST, DESERT, ISLANDS}
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

## 六大素質 UI 顯示用中文標籤,順序對應 PotentialType enum
const POTENTIAL_TYPE_LABELS: Array[String] = ["力量", "體質", "敏捷", "靈巧", "智慧", "信仰"]

## 評級 UI 顯示用標籤,順序對應 RankType enum
const RANK_TYPE_LABELS: Array[String] = ["F", "E", "D", "C", "B", "A", "S", "SS", "SSS"]

## 武器 UI 顯示用中文標籤,順序對應 WeaponType enum
const WEAPON_TYPE_LABELS: Array[String] = ["劍", "弓", "盾", "匕首", "法杖", "捕夢網"]

## 角色清單排序欄位 UI 顯示用中文標籤,順序對應 CharacterSortKey enum
const CHARACTER_SORT_KEY_LABELS: Array[String] = ["等級", "總數值", "格子數", "力量", "體質", "敏捷", "靈巧", "智慧", "信仰"]

## 大地圖地點 UI 顯示用中文標籤,順序對應 MapObjectType enum
const MAP_OBJECT_TYPE_LABELS: Array[String] = ["城鎮", "根據地"]

## 根據地建築類型,見 System/base/building/building_library.gd 與
## 遊戲企劃設定總整理.md 六十八節。前五種(城鎮中心~兵營)是非生產類建築,功能尚未
## 實作;後十二種是生產類建築,兩兩一組對應六大素質的基礎/高階內政。
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
	WOOD, STONE, FOOD, ORE, GOLD, CONTRABAND, FUR, CRAFT,
	BOOK, RESEARCH, FAITH, CURSE,
}

## 根據地資源 UI 顯示用中文標籤,順序對應 ResourceType enum
const RESOURCE_STRING_LABELS: Array[String] = [
	"木材", "石材", "糧食", "鐵礦", "金錢", "贓物", "毛皮", "製作工藝",
	"書本", "科研", "信仰", "詛咒",
]

## 根據地資源 UI 顯示用顯示標籤,順序對應 ResourceType enum
const RESOURCE_TYPE_LABELS: Array[String] = [
	"🪵", "🪨", "🌾", "⛏️", "🪙", "💰", "🐺", "⚒️",
	"📚", "🔬", "🙏", "🩸",
]

## 血統國家 UI 顯示用中文標籤,順序對應 BloodlineNation enum
const BLOODLINE_NATION_LABELS: Array[String] = ["獅", "鷹", "豹", "熊", "龍", "鹿"]

## 血統階級 UI 顯示用中文標籤,順序對應 BloodlineRank enum,跟國家標籤相接組成
## 「獅血」「獅高血」這種完整血統名稱,見 bloodline_full_label()
const BLOODLINE_RANK_LABELS: Array[String] = ["血", "高血"]

## 性別 UI 顯示用符號,順序對應 Gender enum
const GENDER_SYMBOLS: Array[String] = ["♂", "♀"]

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

static func building_type_label(building_type: int) -> String:
	return BUILDING_TYPE_LABELS[building_type]

static func resource_type_label(resource_type: int) -> String:
	return RESOURCE_TYPE_LABELS[resource_type]

static func resource_string_label(resource_type: int) -> String:
	return RESOURCE_STRING_LABELS[resource_type]

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
## 龍→孤島/鹿→高原,對照表見 Spec.md 六、血統國家與地理環境對照表。
const BLOODLINE_NATION_TERRAINS: Array[TerrainType] = [
	TerrainType.PLAINS, TerrainType.FOREST, TerrainType.DESERT,
	TerrainType.MOUNTAINS, TerrainType.ISLANDS, TerrainType.PLATEAU,
]

static func bloodline_nation_terrain(nation: int) -> int:
	return BLOODLINE_NATION_TERRAINS[nation]

## 城鎮外觀對話背景圖(Images/Dialogue/Map/Town/town_<TERRAIN>.png)——檔名直接對應
## TerrainType enum 成員名稱,不另外維護一份路徑陣列(下面 base_building_background_path()
## 同理),見 System/map/map_object.gd 的 MapObject.terrain_type()。同時也是
## Scenes/MapLocation/map_location.gd 進到 TOWN 地點選單時的整頁背景圖。
static func town_background_path(terrain_type: int) -> String:
	return "res://Images/Dialogue/Map/Town/town_%s.png" % TerrainType.keys()[terrain_type]

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
