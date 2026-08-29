class_name PotentialController
extends RefCounted

## 六大素質隨機基礎值:範圍 0~200(見 CombatResolver.judge_dodge()/SkillEffectLibrary
## rank_type 不填(-1)= 六項素質的成長評級各自獨立隨機(維持原本行為);指定時,六項
## 素質各自用 RankDrawTable.roll(rank_type) 獨立骰一次「這項素質實際落在哪個 rank」
## (集中在 rank_type 附近、偶爾探低,不保證六項都精準命中 rank_type),避免同一
## rank_type 底下六項素質被鎖進同一區間、看起來像整批拉滿,見 _random_ratio()。
static func get_random_potential(rank_type: int = -1) -> Potential:
	return Potential.new(
		Util.get_random_int(0, 30),
		Util.get_random_int(0, 30),
		Util.get_random_int(0, 30),
		Util.get_random_int(0, 30),
		Util.get_random_int(0, 30),
		Util.get_random_int(0, 30),
		_random_ratio(rank_type),
		_random_ratio(rank_type),
		_random_ratio(rank_type),
		_random_ratio(rank_type),
		_random_ratio(rank_type),
		_random_ratio(rank_type)
	)

## rank_type 不填(-1)沿用原本 BASE_RATIO~MAX_RATIO 全區間隨機(不經過 RankDrawTable,
## 純粹整段亂數,涵蓋血統疊加前後都可能出現的完整範圍);指定時,先用
## RankDrawTable.roll() 依 rank_type 那一列權重(跟 PartyController 骰隊員評級同一張
## 表)骰出這項素質「實際」落在哪個 rank,再於那個 rank 對應的 ratio 區間內取隨機值
## ——不再直接拿 rank_type 本身當區間,六項素質才會因此各自浮動,而不是全部精準卡
## 在同一級。這裡骰出的還只是血統疊加「前」的值,見 CharacterController.
## get_random_character() 生成後再呼叫 BloodlineLibrary.apply_to_potential() 疊加。
static func _random_ratio(rank_type: int) -> float:
	if rank_type == -1:
		return Util.get_random_float(Potential.BASE_RATIO, Potential.MAX_RATIO)
	var stat_rank := RankDrawTable.roll(rank_type)
	var lower := Potential.BASE_RATIO + Potential.RANK_GAP * stat_rank
	return Util.get_random_float(lower, lower + Potential.RANK_GAP)
