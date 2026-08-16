class_name PotentialInheritance
extends RefCounted

## 素質/潛力遺傳計算:父母平均值 + 隨機變量。六項素質與六項 ratio 各自獨立計算,
## 不強制總和一致。血統對 ratio 的加成不在這裡處理,見 BloodlineLibrary.apply_to_potential()
## ——「父母遺傳」與「血統加成」是兩個獨立步驟,由 InheritanceController 銜接。

static func inherit(father_potential: Potential, mother_potential: Potential) -> Potential:
	return Potential.new(
		_inherit_stat(father_potential.strength, mother_potential.strength),
		_inherit_stat(father_potential.vitality, mother_potential.vitality),
		_inherit_stat(father_potential.agility, mother_potential.agility),
		_inherit_stat(father_potential.dexterity, mother_potential.dexterity),
		_inherit_stat(father_potential.intelligence, mother_potential.intelligence),
		_inherit_stat(father_potential.mentality, mother_potential.mentality),
		_inherit_ratio(father_potential.strength_ratio, mother_potential.strength_ratio),
		_inherit_ratio(father_potential.vitality_ratio, mother_potential.vitality_ratio),
		_inherit_ratio(father_potential.agility_ratio, mother_potential.agility_ratio),
		_inherit_ratio(father_potential.dexterity_ratio, mother_potential.dexterity_ratio),
		_inherit_ratio(father_potential.intelligence_ratio, mother_potential.intelligence_ratio),
		_inherit_ratio(father_potential.mentality_ratio, mother_potential.mentality_ratio)
	)

## 素質基礎值:父母平均 × (1 ± 10%),clamp 到 [POTENTIAL_STAT_MIN, POTENTIAL_STAT_MAX]
static func _inherit_stat(father_value: float, mother_value: float) -> float:
	var theoretical := (father_value + mother_value) / 2.0
	var variance := InheritanceConstants.POTENTIAL_STAT_VARIANCE_RATIO
	var multiplier := Util.get_random_float(1.0 - variance, 1.0 + variance)
	return clampf(theoretical * multiplier, InheritanceConstants.POTENTIAL_STAT_MIN, InheritanceConstants.POTENTIAL_STAT_MAX)

## 潛力 ratio:父母平均 ± 0.2(絕對值),clamp 到 [POTENTIAL_RATIO_MIN, POTENTIAL_RATIO_MAX]
static func _inherit_ratio(father_ratio: float, mother_ratio: float) -> float:
	var theoretical := (father_ratio + mother_ratio) / 2.0
	var variance := InheritanceConstants.POTENTIAL_RATIO_VARIANCE
	var offset := Util.get_random_float(-variance, variance)
	return clampf(theoretical + offset, InheritanceConstants.POTENTIAL_RATIO_MIN, InheritanceConstants.POTENTIAL_RATIO_MAX)
