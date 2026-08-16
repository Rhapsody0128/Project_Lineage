class_name BloodlineController
extends RefCounted

## 目前隨機血統只做「單一國家分裂」:先隨機選 1 個國家,再把 100%(8 個 12.5% STEP)
## 隨機切成該國「平民血統」與「高階血統」兩份,其餘 10 格皆為 0。之後若要做跨國聯姻
## 混血,再擴充成多國混合的版本。
const STEP_COUNT := 8 # Bloodline.TOTAL / Bloodline.STEP = 100 / 12.5

static func get_random_bloodline() -> Bloodline:
	var nation: int = Util.get_random_enum_value(GameEnums.BloodlineNation)
	var noble_steps := Util.get_random_int(0, STEP_COUNT + 1)
	var common_steps := STEP_COUNT - noble_steps

	var percentages: Array[float] = []
	percentages.resize(GameEnums.BloodlineNation.size() * Bloodline.RANK_COUNT)
	percentages.fill(0.0)
	percentages[Bloodline.index_of(nation, GameEnums.BloodlineRank.COMMON)] = common_steps * Bloodline.STEP
	percentages[Bloodline.index_of(nation, GameEnums.BloodlineRank.NOBLE)] = noble_steps * Bloodline.STEP

	return Bloodline.new(percentages)
