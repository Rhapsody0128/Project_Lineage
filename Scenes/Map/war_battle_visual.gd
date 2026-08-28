class_name WarBattleVisual
extends Node2D

## WarBattle 在地圖上的顯示——純顯示,不做點擊/命中判定(比照
## Scenes/Map/roaming_enemy_visual.gd),而且靜止不動(不像 RoamingEnemy 會遊蕩),
## 不需要逐幀位移動畫。沒有專屬美術資源,用雙色圓餅(GameEnums.bloodline_nation_color()
## 各自的顏色)+ 十字圖示代表兩國在此交戰,不臨時生一套新視覺風格。

const RADIUS := 26.0
const CROSSED_SWORDS := "⚔"

var battle: WarBattle
var _label: Label


func setup(p_battle: WarBattle) -> void:
	battle = p_battle
	position = battle.position

	_label = Label.new()
	_label.text = CROSSED_SWORDS
	_label.add_theme_font_size_override("font_size", 28)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 4)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.position = Vector2(-RADIUS, -RADIUS)
	_label.size = Vector2(RADIUS * 2.0, RADIUS * 2.0)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)

	queue_redraw()


## 依 battle_progress 決定哪半邊比較亮,讓玩家不用點進面板也能大致看出誰在優勢。
func update_visual() -> void:
	queue_redraw()


func _draw() -> void:
	if battle == null:
		return
	var color_a := GameEnums.bloodline_nation_color(battle.nation_a)
	var color_b := GameEnums.bloodline_nation_color(battle.nation_b)
	var brighten_a := 1.0 if battle.battle_progress >= 0.0 else 0.6
	var brighten_b := 1.0 if battle.battle_progress <= 0.0 else 0.6
	draw_circle(Vector2.ZERO, RADIUS, Color.BLACK, false, 3.0, true)
	_draw_half_circle(color_a * Color(brighten_a, brighten_a, brighten_a, 1.0), -PI / 2.0, PI / 2.0)
	_draw_half_circle(color_b * Color(brighten_b, brighten_b, brighten_b, 1.0), PI / 2.0, PI * 1.5)


func _draw_half_circle(color: Color, angle_from: float, angle_to: float) -> void:
	var points := PackedVector2Array([Vector2.ZERO])
	var steps := 16
	for i in range(steps + 1):
		var angle: float = lerp(angle_from, angle_to, float(i) / float(steps))
		points.append(Vector2(cos(angle), sin(angle)) * RADIUS)
	draw_polygon(points, PackedColorArray([color]))
