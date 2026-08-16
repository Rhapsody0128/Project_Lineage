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


static func roll_pregnancy() -> bool:
	return Util.get_random_float(0.0, 100.0) < PREGNANCY_CHANCE
