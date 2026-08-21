class_name AgingRule
extends RefCounted

## 老年線/死亡線與死亡機率判定規則,由 WorldTimeEventLibrary._age_up() 每年呼叫。醫療所
## (CLINIC)等級會同時延後兩條線(見 get_aging_line()/get_death_line()),兩條線目前是
## 全域參數,尚未支援角色個體差異(之後如果要做「這個角色天生體質特別硬朗」之類的效果,
## 從這裡的常數/公式擴充即可,見 CLAUDE.md「老年與死亡」)。

## 未建醫療所(CLINIC Lv0)時的預設門檻。
const BASE_AGING_LINE := 50
const BASE_DEATH_LINE := 80
## CLINIC 每升一級,兩條線各自往後延這麼多歲(0→1、1→2...每級都是同樣的量,不是漸增)。
const CLINIC_LINE_BONUS_PER_LEVEL := 5

## 死亡機率曲線的指數:t = 年齡在「衰老線~死亡線」之間的比例(0~1),機率 = t^指數 * 100。
## 指數 > 1 是加速型(前期低、接近死亡線才陡升)。
const DEATH_CHANCE_CURVE_EXPONENT := 2.0

## 衰老特性:全素質固定打七折(不隨年齡繼續往下掉),透過 CharacterTrait.stat_multiplier
## 套用,見 Character._trait_stat_multiplier()。
const AGING_TRAIT_NAME := "衰老"
const AGING_TRAIT_DESCRIPTION := "年老體衰，全素質下降"
const AGING_STAT_MULTIPLIER := 0.7


static func get_aging_line() -> int:
	return BASE_AGING_LINE + CLINIC_LINE_BONUS_PER_LEVEL * BaseBuildingProgressStore.get_level(GameEnums.BuildingType.CLINIC)


static func get_death_line() -> int:
	return BASE_DEATH_LINE + CLINIC_LINE_BONUS_PER_LEVEL * BaseBuildingProgressStore.get_level(GameEnums.BuildingType.CLINIC)


static func is_aged(character: Character) -> bool:
	return character.age >= get_aging_line()


## 死亡機率(百分比)。未達衰老線 0%,達到/超過死亡線 100%,中間依 DEATH_CHANCE_CURVE_EXPONENT
## 的加速曲線內插。
static func get_death_chance_percent(character: Character) -> float:
	var death_line := get_death_line()
	if character.age >= death_line:
		return 100.0
	var aging_line := get_aging_line()
	if character.age < aging_line:
		return 0.0
	var t := float(character.age - aging_line) / float(death_line - aging_line)
	return pow(t, DEATH_CHANCE_CURVE_EXPONENT) * 100.0


static func roll_death(character: Character) -> bool:
	return Util.get_random_float(0.0, 100.0) < get_death_chance_percent(character)


static func has_aging_trait(character: Character) -> bool:
	for character_trait in character.traits:
		if character_trait.is_aging:
			return true
	return false


static func create_aging_trait() -> CharacterTrait:
	var aging_trait := CharacterTrait.new(AGING_TRAIT_NAME, AGING_TRAIT_DESCRIPTION, GameEnums.TraitPolarity.NEGATIVE)
	aging_trait.stat_multiplier = AGING_STAT_MULTIPLIER
	aging_trait.is_aging = true
	return aging_trait
