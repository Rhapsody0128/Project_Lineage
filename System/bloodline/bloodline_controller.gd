class_name BloodlineController
extends RefCounted

## 目前隨機血統只做「單一國家分裂」:先隨機選 1 個國家,再把 100%(8 個 12.5% STEP)
## 隨機切成該國「平民血統」與「高階血統」兩份,其餘 10 格皆為 0。之後若要做跨國聯姻
## 混血,再擴充成多國混合的版本。
const STEP_COUNT := 8 # Bloodline.TOTAL / Bloodline.STEP = 100 / 12.5

## rank_type/nation 不填(-1)= 維持原本隨機(國家隨機選、NOBLE/COMMON 比例隨機切);
## rank_type 指定時直接當 noble_steps 用——STEP_COUNT(8)跟 RankType 的 9 個值(0~8)
## 剛好對齊,Character.compute_noble_bloodline_rank() 换算回來的 RankType 恰好等於
## noble_steps,所以能精準命中目標 rank,不需要另外設計公式。nation 指定時整份血統
## 都落在該國,不受 rank_type 是否指定影響,兩者互相獨立。
static func get_random_bloodline(rank_type: int = -1, nation: int = -1) -> Bloodline:
	var chosen_nation: int = nation if nation != -1 else Util.get_random_enum_value(GameEnums.BloodlineNation)
	var noble_steps: int = rank_type if rank_type != -1 else Util.get_random_int(0, STEP_COUNT + 1)
	var common_steps := STEP_COUNT - noble_steps

	var percentages: Array[float] = []
	percentages.resize(GameEnums.BloodlineNation.size() * Bloodline.RANK_COUNT)
	percentages.fill(0.0)
	percentages[Bloodline.index_of(chosen_nation, GameEnums.BloodlineRank.COMMON)] = common_steps * Bloodline.STEP
	percentages[Bloodline.index_of(chosen_nation, GameEnums.BloodlineRank.NOBLE)] = noble_steps * Bloodline.STEP

	return Bloodline.new(percentages)
