class_name PregnancyRule
extends RefCounted

## 懷孕/生產規則,見 WorldTimeEventLibrary(每月骰懷孕、累積月數滿了產下孩子)。

const MONTHS_TO_BIRTH := 10
## 目前先寫死 100%,之後可能依素質/年齡調整
const PREGNANCY_CHANCE := 100.0


## 是否符合懷孕資格:女性、已婚(mate != null)、目前未懷孕
static func is_eligible(character: Character) -> bool:
	return (
		character.gender == GameEnums.Gender.FEMALE
		and character.mate != null
		and not character.is_pregnant
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


static func roll_pregnancy() -> bool:
	return Util.get_random_float(0.0, 100.0) < PREGNANCY_CHANCE
