class_name FamilyTreeUnit
extends RefCounted

## 祖譜樹的節點單位:代表「一對夫妻」或「一個單身角色」。FamilyTreeBuilder.build()
## 產出的圖以這個為節點,generation 由上至下從 1 起算,parent_unit/child_units
## 是畫連接線用的樹狀連結(見 family_tree_builder.gd 的已知限制:同一 primary/partner
## 只認第一條找到的血親線,不處理近親聯姻造成的第二條連結)。

var primary: Character
var partner: Character = null
var generation: int = 1
var parent_unit: FamilyTreeUnit = null
var child_units: Array[FamilyTreeUnit] = []
