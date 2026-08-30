class_name Character
extends RefCounted

## 角色技能數量上限——UI(CharacterDetailView 技能格)跟規則層(SkillLearnFlow 學技能滿了
## 要跳替換/放棄彈窗)共用同一個數字來源,不要各自維護一份。
const MAX_SKILLS := 4

## 血量上限與 battle_cost 佔位格數掛勾(見 BattleCostController 的 MIN_CELLS/MAX_CELLS),
## 格數越多站位越大,血量上限越高
const COST_HP_MAP := {
	3: 600,
	4: 700,
	5: 800,
	6: 900,
	7: 1000,
}

var id: String
var name: String
var last_name: String
var age: int
var gender: GameEnums.Gender
var face_path: String
var traits: Array[Trait]
var potential: Potential
var bloodline: Bloodline
## 高階血統(NOBLE)評分,GameEnums.RankType,見 _compute_noble_bloodline_rank()——
## 跟 Potential 的 xxx_rank 欄位同一套慣例:建立角色當下算好存欄位,不隨後續變動,
## UI 顯示端(CharacterDetailView 等)直接讀這個欄位,不自己再算一次。
var noble_bloodline_rank: int
## 身分/爵位(GameEnums.RankType),稱號對照見 NobleTitleRule.TITLE_LABELS——跟
## noble_bloodline_rank(血統評分)是兩個獨立欄位,刻意不綁定,允許角色血統區間跟身分
## 不同(例如高血民間平民、低血受封貴族)。隨機產生角色的初始身分依血統分布抽選(見
## NobleTitleRule.rank_for_bloodline(),由 CharacterController 建立後指派);出生小孩
## 改走世襲規則(見 give_birth()/NobleTitleRule.rank_for_inheritance())。預設平民,
## 不在 _init() 內自動計算——各建立管道(隨機/主角/遺傳)各自決定怎麼指派這個欄位。
var title_rank: int = GameEnums.RankType.F
## 目前手持的武器,決定哪些 bind_weapon 技能能施放
var weapon: GameEnums.WeaponType
## 目前手持武器類型提供的素質加成(GameEnums.PotentialType -> 點數)。玩家角色由
## WeaponStore.sync_character() 在加入 CharacterRosterStore 時/裝備變更時寫入;敵人小隊
## 由 PartyController.get_random_party() 產生當下直接指派,跟 WeaponStore 無關。
var weapon_stat_bonus: Dictionary = {}
## 目前手持武器的 rank(GameEnums.RankType),來源同上,UI 顯示用(CharacterDetailView)。
var weapon_rank: GameEnums.RankType = GameEnums.RankType.F
var skill_list: Array[Skill]
var level_system: LevelSystem
var hp: int
## 婚姻/血緣資料,見 遊戲企劃設定總整理.md 二十二~三十一。目前只開欄位,
## 實際寫入邏輯(結婚/生子)留給呼叫端(見 System/event/town/town_tavern_event.gd),
## 這裡不做任何自動判斷。
var parent: Array[Character] = []
var mate: Character = null
var children: Array[Character] = []
## 懷孕狀態,見 PregnancyRule/WorldTimeEventLibrary——每月累積,滿
## PregnancyRule.MONTHS_TO_BIRTH 個月產下孩子後歸零。
var is_pregnant: bool = false
var pregnancy_months: int = 0
## 休產期剩餘月數(見 PregnancyRule.POSTPARTUM_MONTHS),give_birth() 時設定初始值,
## advance_postpartum_recovery() 每月倒數歸零前 PregnancyRule.is_eligible() 一律視為不
## 符合懷孕資格。
var postpartum_months_remaining: int = 0
## 戰場佔位形狀(俄羅斯方塊式多格圖形),用於 PartyEdit 編成畫面的格子佔用判斷
var battle_cost: BattleCost
## 是否為玩家固定主角(CharacterController.get_fixed_protagonist() 建立時設為 true,
## 其餘隨機/遺傳角色一律 false)。目前唯一用途是角色列表畫面擋掉解雇
## (見 character_roster.gd _is_protected_from_dismissal()),避免玩家把主角解雇掉
## 導致遊戲流程卡死。
var is_protagonist: bool = false
## 是否已死亡(見 CharacterDeathController.kill())。死亡角色仍留在 AllCharacterStore
## (祖譜要沿用)但已從 CharacterRosterStore 移除，且不再隨世界時間增齡（見 age_up()）。
var is_dead: bool = false
## 是否已被玩家從角色列表解雇(見 character_roster.gd._dismiss_character())。跟 is_dead
## 同一套慣例:解雇後仍可能留在祖譜親族圖裡(靠 parent/mate/children 參照撐住),但已從
## CharacterRosterStore/AllCharacterStore 移除。狀態顯示見 CharacterStatusRule。
var is_dismissed: bool = false
## 累積傳授過幾次技能(見 BarracksTeachingRule)。不限次數,純粹供 UI 顯示師父目前傳授
## 次數,建立時預設 0,每次成功傳授後遞增。
var taught_skill_count: int = 0

func _init(
	p_name: String,
	p_last_name: String,
	p_age: int,
	p_gender: GameEnums.Gender,
	p_face_path: String,
	p_traits: Array[Trait],
	p_potential: Potential,
	p_bloodline: Bloodline,
	p_weapon: GameEnums.WeaponType,
	p_skill_list: Array[Skill],
	p_level_system: LevelSystem,
	p_battle_cost: BattleCost
) -> void:
	id = Util.generate_uuid()
	name = p_name
	last_name = p_last_name
	age = p_age
	gender = p_gender
	face_path = p_face_path
	traits = p_traits
	potential = p_potential
	bloodline = p_bloodline
	noble_bloodline_rank = compute_noble_bloodline_rank(p_bloodline)
	weapon = p_weapon
	skill_list = p_skill_list
	level_system = p_level_system
	battle_cost = p_battle_cost
	hp = hp_max

## 高階血統評分:Bloodline.get_total_noble_percentage() 每 STEP(12.5)一階換算成
## GameEnums.RankType(E~SSS 共 8 階,STEP*8 剛好等於 Bloodline.TOTAL 上限),對照表見
## 遊戲企劃設定總整理.md:0~<12.5=E、12.5~<25=D、25~<37.5=C、37.5~<50=B、
## 50~<62.5=A、62.5~<75=S、75~<87.5=SS、87.5~100=SSS。公開(非底線開頭)是因為
## CharacterController/InheritanceController 建立角色時,battle_cost 格數要看
## 這個評分先算(見 BattleCostController.cells_for_noble_rank()),
## 必須在 Character 物件實際建立「之前」就拿得到,不能等 _init() 內部才算。
static func compute_noble_bloodline_rank(p_bloodline: Bloodline) -> int:
	var total := p_bloodline.get_total_noble_percentage()

	if total >= 100.0:
		return GameEnums.RankType.SSS

	return mini(
		floori(total / Bloodline.STEP),
		GameEnums.RankType.SS
	)

## 該技能目前是否能施放:未綁定特定武器(NO_WEAPON_BINDING)一律可用,綁了武器的「主動技」
## 要手持相符武器才能用;武器被動(is_passive)例外——bind_weapon 只代表「預設學習時配哪把
## 武器」,傳授學來的被動不論目前手持什麼武器都能觸發(見 BarracksTeachingRule 傳授不擋
## 武器的既有設計,這裡讓被動的「打不出來」限制整個取消,不再只是暫時打不出來)。另外血統
## 覺醒技(Skill.required_bloodline_nation != -1)還要角色持有對應血統
## (Bloodline.get_percentage() > 0),避免這類技能被派給沒有對應血統的角色。
func can_use_skill(skill: Skill) -> bool:
	if not skill.is_passive and skill.bind_weapon != GameEnums.NO_WEAPON_BINDING and skill.bind_weapon != weapon:
		return false
	if skill.required_bloodline_nation != -1:
		if bloodline.get_percentage(skill.required_bloodline_nation, skill.required_bloodline_rank) <= 0.0:
			return false
	return true

## 角色是否已經學會這個技能——用名稱比對,不比對 id 或物件參照:Skill.id 是
## Util.generate_uuid() 隨機產生(見 skill.gd _init()),SkillLibrary.build() 每次呼叫
## 都是全新實例,同一支技能兩次 build() 出來的 id 也不會相同,id 比對一樣會誤判成
## 「沒學過」。技能名稱在 SkillLibrary 裡本來就唯一(存檔/讀檔的 SkillController.get_by_name()
## 已經是同一個假設),用名稱比對才會正確擋下重複學習。原本是
## BarracksTraining.character_knows_skill(),現在傳授(A)/歷練(B)/隊長訓練(E)共用,收斂到
## Character 本身。
func knows_skill(skill: Skill) -> bool:
	for known in skill_list:
		if known.name == skill.name:
			return true
	return false

## 直接學會一個技能,收斂原本散落各處的 skill_list.append() 寫法。
func learn_skill(skill: Skill) -> void:
	skill_list.append(skill)

## 是否學會守護技能(Skill.is_guard_skill,武器仍要相符/未綁定)——用旗標而非顯示名稱
## 字串比對,重新命名技能不會悄悄讓守護判定失效。CombatResolver.resolve_guard() 用。
func knows_guard_skill() -> bool:
	for s in skill_list:
		if s.is_guard_skill and can_use_skill(s):
			return true
	return false

## 找出角色目前持有、掛著指定機制標記(GameEnums.SkillMechanic)且能使用的第一個技能,
## 找不到回傳 null。反擊/完美迴避/反應治療/普通攻擊追加一擊/普通攻擊擴大範圍這類
## 「持有這個武器被動的人就會有這個反應」的判定共用同一個查詢入口,不用旗標字串比對
## 也不用為每種機制各寫一個專屬 bool——一個角色理論上不會同時持有兩個掛同一機制的技能
## (每把武器被動只會有一種機制),找到第一個就回傳。
func find_skill_with_mechanic(mechanic: int) -> Skill:
	for s in skill_list:
		if not can_use_skill(s):
			continue
		if mechanic in s.mechanics:
			return s
	return null

## 姓氏是否顯示只看 last_name 本身是不是空字串,跟角色目前的 title_rank 沒有直接關係
## (見 NobleTitleRule.has_last_name() 的呼叫端註解)——隨機生成角色當下依身分決定要不要
## 抽一個姓氏(見 CharacterController.get_random_character()),小孩則直接繼承父親的
## last_name(見 InheritanceController.create_child(),父親沒姓氏小孩自然也是空字串);
## 之後角色身分升降都不會回頭補上或拔掉已經定下來的姓氏(例如玩家固定主角一開始就帶
## 姓氏,不管他當下是不是騎士以上都要顯示)。
## 出生時抽到的第一個特性(traits[0])固定當作這個人物的形容詞來源——AgingRule 掛的
## 衰老特性一律 append() 加在陣列尾端(見 WorldTimeEventLibrary._process_aging()),
## 不會頂替掉這個位置,所以「出生特性」跟「形容詞」永遠對得上同一個。
var title_adjective: String:
	get: return traits[0].title_adjective if not traits.is_empty() else ""

var title_label: String:
	get: return NobleTitleRule.label_for_rank(title_rank)

## 只有 Dialogue 對話名牌/內文,以及聯姻(BaseMarriageEvent)、告白(TownTavernEvent 的
## 搭訕/求婚流程)這兩個事件才呈現這個完整格式,不要自己拼字串:「形容詞+爵位稱號」用
## 「」括起來接在姓名前面,例如「勇猛的騎士」威廉 · 華勒斯。其餘一般 UI(角色詳情/
## 角色列表/酒館招募等)一律改讀 display_name,只顯示姓名不帶頭銜。
var title_full_name: String:
	get:
		return "「%s%s」%s" % [title_adjective, title_label, full_name]

## 一般 UI 顯示姓名用這個(角色詳情面板/角色列表/兵營各分頁/歷練/家族樹等),只顯示
## given name,不含姓氏也不含形容詞+爵位頭銜(見使用者需求)——頭銜+姓氏只在 title_full_name
## 呈現(見上方註解)。
var display_name: String:
	get: return name

var full_name: String:
	get: return "%s · %s" % [name, last_name] if not last_name.is_empty() else name

var hp_max: int:
	get: return COST_HP_MAP.get(battle_cost.cells.size(), 600)

var is_disabled: bool:
	get: return hp <= 0

func take_damage(damage_points: int) -> void:
	hp = maxi(hp - damage_points, 0)

func heal(amount: int) -> void:
	hp = mini(hp + amount, hp_max)

## 世界時間每跨過一天,角色回復的血量基準值(未建醫療所時的量,見 WorldTimeEventLibrary
## ._regen_hp()——實際回復量是這個基準值 + 醫療所目前等級 + 休息中額外加成,呼叫端算好了
## 才傳進來)。
const DAILY_HP_REGEN := 3

## 玩家在城鎮/根據地選擇「休息」時(MapSessionStore.is_resting),額外疊加的每日回血量,
## 見 WorldTimeEventLibrary._regen_hp()。
const RESTING_HP_REGEN_BONUS := 10

func regen_daily_hp(amount: int = DAILY_HP_REGEN) -> void:
	heal(amount)

## 結為配偶,雙向寫入 mate(資格判定見 MarriageRule.can_propose())
func marry(target_character: Character) -> void:
	mate = target_character
	target_character.mate = self

## 世界時間每跨過一年時呼叫(見 WorldTimeEventLibrary),年紀 +1。未滿成人隨機池
## 起始年齡(CharacterController.MIN_AGE)的角色一定是遺傳出生的小孩(一般隨機角色
## 一開始就是成人),年紀增長跨過 FaceController 的頭像級距時一併刷新 face_path;
## 剛好跨過 MIN_AGE 那一年額外從成人隨機池抽一張換上(僅此一次——已成年角色之後
## age 只會越來越大,不會再落回未成年區間,也不會每年重抽頭像)。
func age_up() -> void:
	if is_dead:
		return
	age += 1
	if age < CharacterController.MIN_AGE:
		face_path = FaceController.get_child_face_path(age, gender)
	elif age == CharacterController.MIN_AGE:
		face_path = FaceController.get_random_face_path(gender)

## 進入懷孕狀態,月數從 0 起算(資格判定見 PregnancyRule.is_eligible(),呼叫端見
## WorldTimeEventLibrary._roll_new_pregnancies())
func start_pregnancy() -> void:
	is_pregnant = true
	pregnancy_months = 0

## 懷孕月數 +1,回傳是否已到分娩月數(PregnancyRule.MONTHS_TO_BIRTH)
func advance_pregnancy() -> bool:
	pregnancy_months += 1
	return pregnancy_months >= PregnancyRule.MONTHS_TO_BIRTH

## 生產:小孩由 InheritanceController.create_child() 依父母資料算出(遺傳公式集中在
## System/inheritance/,不寫在這裡),雙向寫入親子關係並重置懷孕狀態。回傳新生兒——
## 加入 CharacterRosterStore/發 NEWS 是全域註冊/播報,不是角色自身的規則,留給呼叫端
## (WorldTimeEventLibrary)處理。self 一定是母親(PregnancyRule.is_eligible() 限定
## gender == FEMALE 才能懷孕),mate 在懷孕當下已確保非 null,故不需要額外 null 分支。
func give_birth() -> Character:
	var birth_order := children.size() + 1
	var child := InheritanceController.create_child(mate, self)
	var new_parents: Array[Character] = [self, mate]
	child.parent = new_parents
	child.title_rank = NobleTitleRule.rank_for_inheritance(title_rank, mate.title_rank, birth_order)
	children.append(child)
	mate.children.append(child)
	is_pregnant = false
	pregnancy_months = 0
	postpartum_months_remaining = PregnancyRule.postpartum_months()
	return child

## 休產期每月倒數(見 WorldTimeEventLibrary._advance_postpartum_recovery()),歸零後不再
## 繼續遞減負值。
func advance_postpartum_recovery() -> void:
	if postpartum_months_remaining > 0:
		postpartum_months_remaining -= 1

func gain_exp(exp_amount: int) -> void:
	level_system.gain_exp(exp_amount)

func _get_real_potential(initial_potential: float, ratio: float) -> float:
	return (initial_potential + ratio * level_system.potential_level_constant) * _trait_stat_multiplier()

## 全部特性 stat_multiplier 的連乘(見 Trait.stat_multiplier),目前只有
## AgingRule 建立的衰老特性會偏離 1.0——素質全面下降透過既有的 strength/agility/...
## getter 自動套用到戰鬥/生產/UI 全部讀取點，不用另外修改 CombatResolver/BaseProduction。
func _trait_stat_multiplier() -> float:
	var multiplier := 1.0
	for character_trait in traits:
		multiplier *= character_trait.stat_multiplier
	return multiplier

## 手持武器提供的素質加成——套用完潛力+成長+特性乘算之後直接加點數,不參與特性乘算
## (武器加成不會被衰老等 stat_multiplier 打折)。
func get_weapon_stat_bonus(potential_type: int) -> float:
	return float(weapon_stat_bonus.get(potential_type, 0))

var strength: float:
	get: return _get_real_potential(potential.strength, potential.strength_ratio) + get_weapon_stat_bonus(GameEnums.PotentialType.STRENGTH)
var agility: float:
	get: return _get_real_potential(potential.agility, potential.agility_ratio) + get_weapon_stat_bonus(GameEnums.PotentialType.AGILITY)
var dexterity: float:
	get: return _get_real_potential(potential.dexterity, potential.dexterity_ratio) + get_weapon_stat_bonus(GameEnums.PotentialType.DEXTERITY)
var vitality: float:
	get: return _get_real_potential(potential.vitality, potential.vitality_ratio) + get_weapon_stat_bonus(GameEnums.PotentialType.VITALITY)
var intelligence: float:
	get: return _get_real_potential(potential.intelligence, potential.intelligence_ratio) + get_weapon_stat_bonus(GameEnums.PotentialType.INTELLIGENCE)
var mentality: float:
	get: return _get_real_potential(potential.mentality, potential.mentality_ratio) + get_weapon_stat_bonus(GameEnums.PotentialType.MENTALITY)

func get_potential(potential_type: int) -> float:
	match potential_type:
		GameEnums.PotentialType.STRENGTH:
			return strength
		GameEnums.PotentialType.AGILITY:
			return agility
		GameEnums.PotentialType.DEXTERITY:
			return dexterity
		GameEnums.PotentialType.VITALITY:
			return vitality
		GameEnums.PotentialType.INTELLIGENCE:
			return intelligence
		GameEnums.PotentialType.MENTALITY:
			return mentality
		_:
			return 0.0

## 素質的成長評級(GameEnums.RankType,依 Potential 建立當下算好的 ratio 決定,
## 不隨等級變動),UI 顯示用,例如角色面板的雷達圖標籤。
func get_potential_rank(potential_type: int) -> int:
	match potential_type:
		GameEnums.PotentialType.STRENGTH:
			return potential.strength_rank
		GameEnums.PotentialType.AGILITY:
			return potential.agility_rank
		GameEnums.PotentialType.DEXTERITY:
			return potential.dexterity_rank
		GameEnums.PotentialType.VITALITY:
			return potential.vitality_rank
		GameEnums.PotentialType.INTELLIGENCE:
			return potential.intelligence_rank
		GameEnums.PotentialType.MENTALITY:
			return potential.mentality_rank
		_:
			return GameEnums.RankType.E
