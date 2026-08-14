class_name PotentialController
extends RefCounted

## 六大素質隨機基礎值:範圍 0~200(見 CombatResolver.judge_dodge()/SkillEffectLibrary
## 傷害公式的註解,兩者都是照這個尺度設計係數),之前誤寫成 0~50,導致防禦素質
## 遠低於「攻擊素質*技能倍率」,傷害公式的 min(ratio,1.0) 幾乎每次都封頂在 1.0,
## 同一場範圍技能打到的每個目標因此看起來都拿到一樣的傷害數字(防禦其實沒在發揮作用)。
static func get_random_potential() -> Potential:
	return Potential.new(
		Util.get_random_int(0, 100),
		Util.get_random_int(0, 100),
		Util.get_random_int(0, 100),
		Util.get_random_int(0, 100),
		Util.get_random_int(0, 100),
		Util.get_random_int(0, 100),
		Util.get_random_float(0.5, 2.0),
		Util.get_random_float(0.5, 2.0),
		Util.get_random_float(0.5, 2.0),
		Util.get_random_float(0.5, 2.0),
		Util.get_random_float(0.5, 2.0),
		Util.get_random_float(0.5, 2.0)
	)
