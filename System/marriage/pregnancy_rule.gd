class_name PregnancyRule
extends RefCounted

## 懷孕/生產規則,見 WorldTimeEventLibrary(每月骰懷孕、累積月數滿了產下孩子)。

const MONTHS_TO_BIRTH := 10

## 每月懷孕機率的基準值(雙方都年輕、無子女時)。不是 100%——已婚不代表每月必中。
const BASE_PREGNANCY_CHANCE_PERCENT := 6.0 
## 每多一個孩子，懷孕機率就乘上這個係數（指數衰減）， 
## 模擬子女越多，後續生育機率越低。 
## 例如基準 6%、係數 0.5 時： ## 0 個孩子=6.00%、1 個=3%、2 個=1.5%、3 個=0.75%……
## 越多孩子，懷孕機率越低，但不會直接歸零，會隨子女數增加逐步趨近 0。 
const CHILD_COUNT_DESIRE_DECAY := 0.5

## 休產期(月):產下孩子後這段月數內不列入懷孕資格,模擬產後恢復期不會馬上又懷上下一胎。
## 見 Character.postpartum_months_remaining(give_birth() 設定初始值、
## advance_postpartum_recovery() 每月倒數,呼叫點見 WorldTimeEventLibrary
## ._advance_postpartum_recovery())。
const POSTPARTUM_MONTHS := 12

## 「產後調理」科技線(TechEffectType.POSTPARTUM_MONTHS_SUB)在基準值上扣減,下限
## clamp 在 0(不會是負數月數)。
static func postpartum_months() -> int:
	var reduced := POSTPARTUM_MONTHS - int(TechStore.get_bonus(GameEnums.TechEffectType.POSTPARTUM_MONTHS_SUB))
	return maxi(reduced, 0)


## 是否符合懷孕資格:女性、已婚(mate != null)、目前未懷孕、不在休產期內。年老導致機率
## 歸零(見 get_pregnancy_chance_percent())不算在「資格」裡,而是併入機率判定本身。
static func is_eligible(character: Character) -> bool:
	return (
		character.gender == GameEnums.Gender.FEMALE
		and character.mate != null
		and not character.is_pregnant
		and character.postpartum_months_remaining <= 0
	)


## 從配偶雙方裡解出懷孕判定該用的那一位(FEMALE 的一方)。CharacterRosterStore 只保證
## 「發起告白的一方」被加入(見 town_tavern_event.gd 的 stranger 未加入 roster 的已知
## 限制),配偶可能只存在 character.mate 參照裡、本身不在 roster 中,所以呼叫端(見
## WorldTimeEventLibrary._roll_new_pregnancies())不能只拿 for 迴圈走到的 character 本人
## 判斷,要連同 mate 一起納入,兩者哪個是 FEMALE 才是真正該判定的對象。character 未婚
## (mate == null)時回傳 null。
static func resolve_pregnancy_candidate(character: Character) -> Character:
	if character.mate == null:
		return null
	return character if character.gender == GameEnums.Gender.FEMALE else character.mate


## 懷孕機率(百分比)。父母任一方已進入衰老期(AgingRule.is_aged())直接視為 0%——
## 老年喪失生育能力,不再套用子女數量的指數衰減。否則以 BASE_PREGNANCY_CHANCE_PERCENT
## 為基準,依母親目前子女數量(wife.children.size())做指數衰減,見上方常數註解。
## 「孕育之道」科技線(TechEffectType.PREGNANCY_CHANCE_ADD)在指數衰減之後再加,不吃
## 子女數量衰減(不然子女越多這條科技反而越沒用)。
static func get_pregnancy_chance_percent(wife: Character) -> float:
	if AgingRule.is_aged(wife) or AgingRule.is_aged(wife.mate):
		return 0.0
	var base := BASE_PREGNANCY_CHANCE_PERCENT * pow(CHILD_COUNT_DESIRE_DECAY, wife.children.size())
	return base + TechStore.get_bonus(GameEnums.TechEffectType.PREGNANCY_CHANCE_ADD)


static func roll_pregnancy(wife: Character) -> bool:
	return Util.get_random_float(0.0, 100.0) < get_pregnancy_chance_percent(wife)
