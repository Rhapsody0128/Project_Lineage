class_name BattleCost
extends RefCounted

# =========================================================
# 角色的戰場佔位形狀:一組相鄰的格子(俄羅斯方塊式多格圖形)。
# cells[0] 固定是 Vector2i.ZERO——角色本人站立的「佔位格」,
# 也是形狀旋轉的軸心,其餘格子都是相對這一格的偏移量。
# =========================================================

var cells: Array[Vector2i]

func _init(p_cells: Array[Vector2i]) -> void:
	cells = p_cells

## 順時針旋轉 90 度,回傳新的 BattleCost(軸心固定在原點,旋轉公式單純)
func rotate_cw() -> BattleCost:
	var rotated: Array[Vector2i] = []
	for cell in cells:
		rotated.append(Vector2i(-cell.y, cell.x))
	return BattleCost.new(rotated)

func rotate_ccw() -> BattleCost:
	var rotated: Array[Vector2i] = []
	for cell in cells:
		rotated.append(Vector2i(cell.y, -cell.x))
	return BattleCost.new(rotated)

## bounding box 左上角/右下角(以格為單位)
func bounds_min() -> Vector2i:
	var result := cells[0]
	for cell in cells:
		result = Vector2i(mini(result.x, cell.x), mini(result.y, cell.y))
	return result

func bounds_max() -> Vector2i:
	var result := cells[0]
	for cell in cells:
		result = Vector2i(maxi(result.x, cell.x), maxi(result.y, cell.y))
	return result

## 形狀 bounding box 的中心,相對佔位格(cells[0])的偏移量,四捨五入到整數格。
## 拖曳擺放時要用「整體形狀」對齊滑鼠游標,而不是佔位格本身——佔位格只是
## BATTLE 站位用的軸心,不代表這個形狀的視覺重心(見 PartyEditAvailabilityLayer)。
func center_offset() -> Vector2i:
	var min_c := bounds_min()
	var max_c := bounds_max()
	return Vector2i(roundi((min_c.x + max_c.x) / 2.0), roundi((min_c.y + max_c.y) / 2.0))

## 把 cells 裡任一格重新當作佔位格(新原點),其餘格子重算相對偏移——輪廓/總格數不變,
## 只是換一格當站立軸心。供「變換隊形→重抽佔位」使用(見 BattleCostController.reroll_anchor())。
func rebase_anchor(new_anchor_index: int) -> BattleCost:
	var anchor := cells[new_anchor_index]
	var rebased: Array[Vector2i] = []
	for cell in cells:
		rebased.append(cell - anchor)
	return BattleCost.new(rebased)
