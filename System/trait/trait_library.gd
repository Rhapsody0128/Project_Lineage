class_name TraitLibrary
extends RefCounted

## 個性/特質總表,取自「遊戲企劃設定總整理.md」五、角色個性系統的範例。個性與技能完全
## 分開,是角色天生特徵;目前僅有資料模型與描述文字,機制效果(命中率/戰鬥AI 傾向等)
## 尚未實作,見 CLAUDE.md 已知待辦。比照 SkillLibrary/SkillController 的分層慣例:這裡只
## 管靜態資料表,選取邏輯(隨機抽幾個)在 TraitController。

static func build() -> Array[Trait]:
	var library: Array[Trait] = []
	library.append(Trait.new("目盲", "命中率降低", GameEnums.TraitPolarity.NEGATIVE, "目盲的"))
	library.append(Trait.new("勇猛", "提高攻擊相關能力", GameEnums.TraitPolarity.POSITIVE, "勇猛的"))
	library.append(Trait.new("膽小", "低血量時更容易退縮", GameEnums.TraitPolarity.NEGATIVE, "膽小的"))
	return library
