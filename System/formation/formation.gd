class_name Formation
extends RefCounted

var name: String
var formation_cell_list: Array[FormationCell]

func _init(p_name: String, p_formation_cells: Array[FormationCell]) -> void:
	name = p_name
	formation_cell_list = p_formation_cells

func get_formation_cell(target_position: Vector2i) -> FormationCell:
	for cell in formation_cell_list:
		if cell.position == target_position:
			return cell
	return null
