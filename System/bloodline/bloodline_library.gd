class_name BloodlineLibrary
extends RefCounted

## 血統對六大素質成長潛力(Potential.xxx_ratio)的固有加成表,比照 SkillLibrary
## 的靜態資料表寫法集中管理。血統本身不直接加素質(strength/vitality/...),
## 只加 ratio——ratio 才是「每次成長時的潛力」,最終数值仍由 rank_from_ratio() 換算。
##
## 12 個欄位(索引 = Bloodline.index_of(nation, rank))各自對應一組 6 長度加成陣列,
## 陣列索引順序對齊 GameEnums.PotentialType(STRENGTH/VITALITY/AGILITY/DEXTERITY/
## INTELLIGENCE/MENTALITY)。數值依國家主題(獅→力量/鷹→靈巧/豹→敏捷/熊→體質/
## 龍→智慧/鹿→信仰,見 遊戲企劃設定總整理.md 血統國家對照表),各國同一量級類推:
## 高血主線 1.0/次線 0.6/三線 0.4,平血主線 0.3/次線 0.2/三線 0.1。
static func _ratio_bonus_table() -> Array[Array]:
	var table: Array[Array] = []
	table.resize(GameEnums.BloodlineNation.size() * Bloodline.RANK_COUNT)
	for i in range(table.size()):
		table[i] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]

	# 獅 LION:力量系(高血 STR1.0 VIT0.6 DEX0.4 / 平血 STR0.3 VIT0.2 DEX0.1)
	table[Bloodline.index_of(GameEnums.BloodlineNation.LION, GameEnums.BloodlineRank.NOBLE)] = \
		[1.0, 0.6, 0.0, 0.4, 0.0, 0.0]
	table[Bloodline.index_of(GameEnums.BloodlineNation.LION, GameEnums.BloodlineRank.COMMON)] = \
		[0.3, 0.2, 0.0, 0.1, 0.0, 0.0]

	# 鷹 EAGLE:靈巧系(高血 DEX1.0 AGI0.6 MEN0.4 / 平血 DEX0.3 AGI0.2 MEN0.1)
	table[Bloodline.index_of(GameEnums.BloodlineNation.EAGLE, GameEnums.BloodlineRank.NOBLE)] = \
		[0, 0.0, 0.6, 1.0, 0.0, 0.4]
	table[Bloodline.index_of(GameEnums.BloodlineNation.EAGLE, GameEnums.BloodlineRank.COMMON)] = \
		[0, 0.0, 0.2, 0.3, 0.0, 0.1]

	# 豹 LEOPARD:敏捷系(高血 AGI1.0 DEX0.6 STR0.4 / 平血 AGI0.3 DEX0.2 STR0.1)
	table[Bloodline.index_of(GameEnums.BloodlineNation.LEOPARD, GameEnums.BloodlineRank.NOBLE)] = \
		[0.4, 0, 1.0, 0.6, 0.0, 0.0]
	table[Bloodline.index_of(GameEnums.BloodlineNation.LEOPARD, GameEnums.BloodlineRank.COMMON)] = \
		[0.1, 0.0, 0.3, 0.2, 0.0, 0.0]

	# 熊 BEAR:體質系(高血 VIT1.0 STR0.6 MEN0.4 / 平血 VIT0.3 STR0.2 MEN0.1)
	table[Bloodline.index_of(GameEnums.BloodlineNation.BEAR, GameEnums.BloodlineRank.NOBLE)] = \
		[0.6, 1.0, 0.0, 0.0, 0.0, 0.4]
	table[Bloodline.index_of(GameEnums.BloodlineNation.BEAR, GameEnums.BloodlineRank.COMMON)] = \
		[0.2, 0.3, 0.0, 0.0, 0.0, 0.1]

	# 龍 DRAGON:智慧系(高血 INT1.0 MEN0.6 VIT0.4 / 平血 INT0.3 MEN0.2 VIT0.1)
	table[Bloodline.index_of(GameEnums.BloodlineNation.DRAGON, GameEnums.BloodlineRank.NOBLE)] = \
		[0.0, 0.4, 0.0, 0.0, 1.0, 0.6]
	table[Bloodline.index_of(GameEnums.BloodlineNation.DRAGON, GameEnums.BloodlineRank.COMMON)] = \
		[0.0, 0.1, 0.0, 0.0, 0.3, 0.2]

	# 鹿 DEER:信仰系(高血 MEN1.0 INT0.6 AGI0.4 / 平血 MEN0.3 INT0.2 AGI0.1)
	table[Bloodline.index_of(GameEnums.BloodlineNation.DEER, GameEnums.BloodlineRank.NOBLE)] = \
		[0.0, 0.0, 0.4, 0.0, 0.6, 1.0]
	table[Bloodline.index_of(GameEnums.BloodlineNation.DEER, GameEnums.BloodlineRank.COMMON)] = \
		[0.0, 0.0, 0.1, 0.0, 0.2, 0.3]

	return table

static func get_ratio_bonus(nation: int, rank: int, potential_type: int) -> float:
	return _ratio_bonus_table()[Bloodline.index_of(nation, rank)][potential_type]

## 依 bloodline 的非 0 欄位(各自的百分比 / 100 當權重)加權加總 12 欄位的固有加成,
## 回傳 6 長度陣列,索引對齊 GameEnums.PotentialType
static func compute_ratio_bonuses(bloodline: Bloodline) -> Array[float]:
	var bonuses: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	for entry in bloodline.get_nonzero_entries():
		var weight: float = entry["percentage"] / Bloodline.TOTAL
		var row := _ratio_bonus_table()[Bloodline.index_of(entry["nation"], entry["rank"])]
		for potential_type in range(bonuses.size()):
			bonuses[potential_type] += row[potential_type] * weight
	return bonuses

## 把 compute_ratio_bonuses() 的結果加到 potential 的六個 ratio 上,clamp 到合法範圍,
## 回傳新的 Potential(base 值原封不動照抄)
static func apply_to_potential(potential: Potential, bloodline: Bloodline) -> Potential:
	var bonuses := compute_ratio_bonuses(bloodline)
	var min_ratio := InheritanceConstants.POTENTIAL_RATIO_MIN
	var max_ratio := InheritanceConstants.POTENTIAL_RATIO_MAX
	return Potential.new(
		potential.strength,
		potential.vitality,
		potential.agility,
		potential.dexterity,
		potential.intelligence,
		potential.mentality,
		clampf(potential.strength_ratio + bonuses[GameEnums.PotentialType.STRENGTH], min_ratio, max_ratio),
		clampf(potential.vitality_ratio + bonuses[GameEnums.PotentialType.VITALITY], min_ratio, max_ratio),
		clampf(potential.agility_ratio + bonuses[GameEnums.PotentialType.AGILITY], min_ratio, max_ratio),
		clampf(potential.dexterity_ratio + bonuses[GameEnums.PotentialType.DEXTERITY], min_ratio, max_ratio),
		clampf(potential.intelligence_ratio + bonuses[GameEnums.PotentialType.INTELLIGENCE], min_ratio, max_ratio),
		clampf(potential.mentality_ratio + bonuses[GameEnums.PotentialType.MENTALITY], min_ratio, max_ratio)
	)
