class_name StatModifier
extends RefCounted

## 素質加成/減益修正:一筆代表「某項素質 ±multiplier」(0.2 = +20%,-0.2 = -20%),
## rounds_remaining < 0 是永久生效(被動技能用,例如 A. 智勇兼備),不會被
## BattleCharacter.tick_status_effects() 消耗;>= 0 則是限時 buff/debuff(D. 大將之風/
## E. 降咒),每回合結束倒數 1 回合,到期自動移除。原本是 BattleCharacter 內部的巢狀類別,
## 升成獨立檔案,比照專案其他型別「一檔一類別」的慣例。
var potential_type: GameEnums.PotentialType
var multiplier: float
var rounds_remaining: int

func _init(p_potential_type: GameEnums.PotentialType = 0, p_multiplier: float = 0.0, p_rounds_remaining: int = 0) -> void:
	potential_type = p_potential_type
	multiplier = p_multiplier
	rounds_remaining = p_rounds_remaining
