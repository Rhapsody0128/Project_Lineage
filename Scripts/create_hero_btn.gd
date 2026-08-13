class_name CreateHeroBtn
extends Control

@export var content: Label
@export var title: Label

# 原始 Unity 版本會另外在場景中生成一顆 3D Sphere 作示意,
# 屬於除錯用的暫時視覺效果,2D UI 情境下不再需要,故省略。
func create_hero() -> void:
	var hero := HeroController.get_random_hero()
	title.text = "%s·%s" % [hero.name, hero.last_name]
	content.text = "力量 %.1f  敏捷 %.1f\n體質 %.1f  靈巧 %.1f\n智慧 %.1f  信仰 %.1f" % [
		hero.strength,
		hero.agility,
		hero.vitality,
		hero.dexterity,
		hero.intelligence,
		hero.mentality,
	]
