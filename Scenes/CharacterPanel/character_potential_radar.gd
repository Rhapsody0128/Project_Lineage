class_name CharacterPotentialRadar
extends Control

# =========================================================
# 角色六大素質雷達圖(力量/體質/敏捷/靈巧/智慧/信仰)。
# 純粹畫面呈現,不含任何數值判定邏輯。
#
# 沒有 BattleCharacter(創角/角色面板等日常情境)時,形狀畫的是「潛力 ratio」本身
# (Potential.xxx_ratio,決定評級的那個數字),不是 Character.xxx 那組已含等級加成的
# 即時數值——後者的 base 是跟血統/評級無關的 0~30 先天雜訊,拿來畫形狀會讓形狀跟
# 旁邊標出來的評級對不上(1 級角色 base 雜訊壓過 ratio 貢獻,見
# Character._get_real_potential())。用 ratio 直接對 InheritanceConstants.
# POTENTIAL_RATIO_MAX(潛力 ratio 實際上限,見該檔常數註解——SSS 那一階要 ratio>=2.1
# 才夠,不是字面上的 2.0)線性換算半徑,直接引用同一份常數而不是自己再存一份
# 數字,避免兩邊之後又漂移不同步。不拿評級本身(F=0~SSS=8)當格數,是因為 ratio
# 下限是 0.5,不是 0,直接用 ratio/上限 換算,F 評級的角色自然落在中心以外的位置,
# 不會整個貼死在正中心看起來像「完全沒有潛力」,格線也依同一把尺畫在
# RATIO_RING_VALUES([0.4, 0.8, 1.2, 1.6, 2.0])五圈,不用切太密——這五個刻度不是
# 上限,單純是好讀的參考線,實際外圈邊界是 POTENTIAL_RATIO_MAX。
#
# 從戰鬥場景(點頭像)開啟時會多帶一個 BattleCharacter(見 set_character() 的第二參數)——
# 這時才改用 BattleCharacter.get_potential()(套用完暴擊/被動/buff/debuff 加成後的
# 即時數值)畫形狀,格線維持原本的 RING_COUNT/MAX_VALUE 四等分,因為這裡要看的
# 是「戰場上實際多強」而非血統潛力。標籤兩種情境都只顯示素質名稱+基礎潛力評級
# (例如「力量S」),數值改在 CharacterDetailView 的屬性分頁顯示(見該檔
# _update_potential_labels()),雷達圖本身不重複列數字。
# =========================================================

const AXIS_COUNT := 6
const RING_COUNT := 4
const MAX_VALUE := 200.0
const RATIO_RING_VALUES: Array[float] = [0.4, 0.8, 1.2, 1.6, 2.0]
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


## 沒有 BattleCharacter 時格線畫在 RATIO_RING_VALUES 那幾個 ratio 刻度上(五圈,
## 見檔頭註解),有 BattleCharacter 時維持原本 0~MAX_VALUE 的四等分。
func _ring_fractions() -> Array[float]:
	if _battle_character != null:
		var value_fractions: Array[float] = []
		for ring in range(1, RING_COUNT + 1):
			value_fractions.append(ring / float(RING_COUNT))
		return value_fractions
	var ratio_fractions: Array[float] = []
	for ratio_value in RATIO_RING_VALUES:
		ratio_fractions.append(ratio_value / InheritanceConstants.POTENTIAL_RATIO_MAX)
	return ratio_fractions


func _draw_grid(center: Vector2, radius: float) -> void:
	for fraction in _ring_fractions():
		var ring_radius := radius * fraction
		var points := PackedVector2Array()
		for i in range(AXIS_COUNT + 1):
			points.append(_axis_point(center, ring_radius, i % AXIS_COUNT))
		draw_polyline(points, GRID_COLOR, 1.0)

	for i in range(AXIS_COUNT):
		draw_line(center, _axis_point(center, radius, i), GRID_COLOR, 1.0)


## 潛力 ratio(GameEnums.PotentialType 索引對齊 Potential.xxx_ratio 六個欄位)。
func _potential_ratio(potential_type: int) -> float:
	match potential_type:
		GameEnums.PotentialType.STRENGTH:
			return _character.potential.strength_ratio
		GameEnums.PotentialType.VITALITY:
			return _character.potential.vitality_ratio
		GameEnums.PotentialType.AGILITY:
			return _character.potential.agility_ratio
		GameEnums.PotentialType.DEXTERITY:
			return _character.potential.dexterity_ratio
		GameEnums.PotentialType.INTELLIGENCE:
			return _character.potential.intelligence_ratio
		GameEnums.PotentialType.MENTALITY:
			return _character.potential.mentality_ratio
		_:
			return Potential.BASE_RATIO


## 形狀用的數值換算成 0~1 的半徑比例:有 BattleCharacter 時看即時數值(戰場上實際多強,
## 見檔頭註解),沒有時直接拿 ratio 對 InheritanceConstants.POTENTIAL_RATIO_MAX 線性
## 換算,保證形狀連續反映 ratio 本身(而不是量化過的評級階梯),旁邊軸標籤的評級文字
## 仍是同一個 ratio 換算出來的,兩者不會對不上。
func _value_fraction(potential_type: int) -> float:
	if _battle_character != null:
		return clampf(_battle_character.get_potential(potential_type) / MAX_VALUE, 0.0, 1.0)
	return clampf(_potential_ratio(potential_type) / InheritanceConstants.POTENTIAL_RATIO_MAX, 0.0, 1.0)


func _draw_values(center: Vector2, radius: float) -> void:
	var points := PackedVector2Array()
	for i in range(AXIS_COUNT):
		var fraction := _value_fraction(POTENTIAL_TYPES[i])
		points.append(_axis_point(center, radius * fraction, i))

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
