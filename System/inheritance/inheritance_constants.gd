class_name InheritanceConstants
extends RefCounted

## 遺傳系統集中常數表:血統/素質/潛力各遺傳計算共用同一份,未來新增遺傳因素
## (特殊遺傳/突變等)也統一放這裡,方便集中調整,不要散落進各個 XxxInheritance 檔案。

const CHILD_STARTING_AGE := 1

## 血統變異機率表,key 是變異倍率(字串,配合 Util.get_random_chance_item() 的
## Dictionary[String, float] 簽名),value 是機率權重。實際變量 = 倍率 * Bloodline.STEP。
const BLOODLINE_MUTATION_CHANCES: Dictionary = {
	"0": 60.0, # 普通遺傳
	"1": 30.0, # 輕微變異
	"2": 10.0, # 大變異
}

const POTENTIAL_STAT_VARIANCE_RATIO := 0.1 # 素質理論值 ±10%
const POTENTIAL_STAT_MIN := 0.0
const POTENTIAL_STAT_MAX := 200.0 # 對應 Potential 註解「區間 0-200」

const POTENTIAL_RATIO_VARIANCE := 0.2 # 潛力 ratio 理論值 ±0.2(絕對值,非比例)
const POTENTIAL_RATIO_MIN := Potential.BASE_RATIO
const POTENTIAL_RATIO_MAX := Potential.MAX_RATIO
