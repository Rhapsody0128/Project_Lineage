class_name CharacterTrait
extends RefCounted

var id: String
var name: String
var description: String
var polarity: int

func _init(p_name: String, p_description: String, p_polarity: int) -> void:
	id = Util.generate_uuid()
	name = p_name
	description = p_description
	polarity = p_polarity
