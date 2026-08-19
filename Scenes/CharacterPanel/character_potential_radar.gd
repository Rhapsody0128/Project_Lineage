class_name CharacterPotentialRadar
extends Control

# =========================================================
# 角色六大素質雷達圖(力量/體質/敏捷/靈巧/智慧/信仰)。
# 純粹畫面呈現,只依傳入的 Character 目前數值(已含等級加成)畫圖,
# 不含任何數值判定邏輯。
#
# 從戰鬥場景(點頭像)開啟時會多帶一個 BattleCharacter(見 set_character() 的第二參數)——
# 這時雷達圖形狀本身改用 BattleCharacter.get_potential()(套用完暴擊/被動/buff/debuff
# 加成後的即時數值)。標籤只顯示素質名稱+等級(例如「力量S」),數值改在
# CharacterDetailView 的屬性分頁顯示(見該檔 _update_potential_labels()),
# 雷達圖本身不重複列數字。
# =========================================================

const AXIS_COUNT := 6
const RING_COUNT := 4
const MAX_VALUE := 200.0
const LABEL_MARGIN := 26.0
const FONT_SIZE := 14

## 羊皮紙淺色底配色(CharacterPanel/CharacterRoster/MarriageProposal 三處呼叫端目前
## 都是羊皮紙底,見 character_detail_view.gd)——原本另有一組淡藍/白色系是為深色底
## 調的,但三個呼叫端全部改成羊皮紙底之後就沒有消費者要用它了,直接拿掉,不留一個
## 沒人選的旗標。
const GRID_COLOR := Color(0.35, 0.22, 0.1, 0.35)
const AXIS_LABEL_COLOR := Color(0.28, 0.16, 0.06, 1)
const FILL_COLOR := Color(0.15, 0.35, 0.65, 0.4)
const OUTLINE_COLOR := Color(0.1, 0.3, 0.55, 0.95)

const POTENTIAL_TYPES := [
	GameEnums.PotentialType.STRENGTH,
	GameEnums.PotentialType.VITALITY,
	GameEnums.PotentialType.AGILITY,
	GameEnums.PotentialType.DEXTERITY,
	GameEnums.PotentialType.INTELLIGENCE,
	GameEnums.PotentialType.MENTALITY,
]

var _character: Character
var _battle_character: BattleCharacter


## battle_character 留空(null)代表沒有戰場情境(創角面板等),只顯示基礎潛力數字;
## 有傳入時代表是從戰鬥中點頭像開啟,額外顯示即時數值,並持續每幀重繪跟上戰況變化
## (見 _process())。
func set_character(p_character: Character, p_battle_character: BattleCharacter = null) -> void:
	_character = p_character
	_battle_character = p_battle_character
	set_process(_battle_character != null)
	queue_redraw()


## 只有帶 BattleCharacter(戰鬥中開啟)才需要逐幀重繪——素質會因為 buff/debuff/被動隨戰況
## 即時變動,面板開著的時候要連動更新;沒有 BattleCharacter 時數值不會變,不需要浪費效能。
func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if _character == null:
		return

	var center := size / 2.0
	var radius := minf(size.x, size.y) / 2.0 - LABEL_MARGIN
	if radius <= 0.0:
		return

	_draw_grid(center, radius)
	_draw_values(center, radius)
	_draw_labels(center, radius)


func _axis_point(center: Vector2, radius: float, index: int) -> Vector2:
	var angle := -PI / 2.0 + index * (TAU / AXIS_COUNT)
	return center + Vector2(cos(angle), sin(angle)) * radius


func _draw_grid(center: Vector2, radius: float) -> void:
	for ring in range(1, RING_COUNT + 1):
		var ring_radius := radius * ring / float(RING_COUNT)
		var points := PackedVector2Array()
		for i in range(AXIS_COUNT + 1):
			points.append(_axis_point(center, ring_radius, i % AXIS_COUNT))
		draw_polyline(points, GRID_COLOR, 1.0)

	for i in range(AXIS_COUNT):
		draw_line(center, _axis_point(center, radius, i), GRID_COLOR, 1.0)


## 有 BattleCharacter 時,雷達圖的形狀本身也改畫即時數值(不然形狀跟旁邊標出來的即時數字對不上)。
func _current_value(potential_type: int) -> float:
	if _battle_character != null:
		return _battle_character.get_potential(potential_type)
	return _character.get_potential(potential_type)


func _draw_values(center: Vector2, radius: float) -> void:
	var points := PackedVector2Array()
	for i in range(AXIS_COUNT):
		var value := _current_value(POTENTIAL_TYPES[i])
		var ratio: float = clampf(value / MAX_VALUE, 0.0, 1.0)
		points.append(_axis_point(center, radius * ratio, i))

	if points.size() < 3:
		return

	draw_colored_polygon(points, FILL_COLOR)

	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, OUTLINE_COLOR, 2.0)


func _draw_labels(center: Vector2, radius: float) -> void:
	var font := get_theme_default_font()
	var font_size := FONT_SIZE

	for i in range(AXIS_COUNT):
		var potential_type: int = POTENTIAL_TYPES[i]
		var rank: int = _character.get_potential_rank(potential_type)
		var label := "%s%s" % [GameEnums.potential_label(potential_type), GameEnums.rank_label(rank)]

		var anchor := _axis_point(center, radius + LABEL_MARGIN * 0.7, i)
		var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		draw_string(
			font,
			anchor - Vector2(text_size.x / 2.0, -text_size.y / 4.0),
			label,
			HORIZONTAL_ALIGNMENT_CENTER,
			-1,
			font_size,
			AXIS_LABEL_COLOR
		)
