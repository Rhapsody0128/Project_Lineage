class_name BattleCostView
extends Control

# =========================================================
# 純視覺元件:把一個 BattleCost 的多格圖形畫出來,佔位格
# (cells[0],軸心)額外疊一張朝右站立的角色 icon。
# 不含任何拖曳/合法性判斷邏輯——CharacterPanel、CharacterCard、
# PartyEdit 的網格擺放層都各自唯讀重用這顆元件。
# =========================================================

## 每格直接填武器代表色(見 GameEnums.weapon_border_color()),不再另外描邊——
## 佔位格(anchor)用比較高的不透明度,跟其餘格子有點區隔,方便看出軸心在哪一格。
const CELL_FILL_ALPHA := 0.75
const ANCHOR_CELL_FILL_ALPHA := 0.95

# 佔位格圖示暫用 Warrier idle_Right 那一幀佔位(見 Images/Warrier/animated_sprite_2d.tscn)
const STANDEE_ATLAS_PATH := "res://Images/Warrier/character_walk.png"
const STANDEE_REGION := Rect2(0, 46, 32, 46)

## 隊長標記:疊在佔位格右上角的小旗子圖示,跟 BattleUnitVisual/BattlePartyRoster
## 共用同一張圖(見 GameEnums.LEADER_FLAG_ICON_PATH),標記邏輯要一致。
const LEADER_ICON_WIDTH_RATIO := 0.55

@export var cell_size: float = 24.0:
	set(value):
		cell_size = value
		_update_layout()

var battle_cost: BattleCost:
	set(value):
		battle_cost = value
		_update_layout()

## 決定每格填色(見 GameEnums.weapon_border_color())。呼叫端(CharacterCard、
## PartyEdit 已放置圖層、CharacterPanel)一律從 character.weapon 帶進來,角色一定持有
## 真實武器,這裡的預設值只是節點建立當下、賦值前的過渡狀態。
var weapon: GameEnums.WeaponType = GameEnums.WeaponType.SWORD:
	set(value):
		weapon = value
		queue_redraw()

## 隊長標記:疊在佔位格右上角一面小旗子圖示(見 LEADER_ICON_WIDTH_RATIO)。
## 呼叫端依當下的隊長判斷結果帶進來(PartyEdit 的 PartyEditGrid.get_leader()、
## 戰鬥中的 BattleCharacter.is_leader)。
var is_leader: bool = false:
	set(value):
		is_leader = value
		queue_redraw()

## 形狀 bounding box 左上角(以格為單位)。這顆 view 的本地座標原點是
## bounding box 角落,不是佔位格軸心——把它擺到網格上時,呼叫端要用這個值
## 換算佔位格軸心對應的實際位置。
var bounds_min: Vector2i = Vector2i.ZERO

var _standee_texture: Texture2D
var _leader_icon_texture: Texture2D

## true 時,_process() 每一幀都會把這顆 view 的 global_position 對齊到滑鼠游標
## (置中),用於拖曳浮動預覽——見 build_centered_drag_preview()。一般用途
## (roster 卡片、已放置角色圖示、CharacterPanel 展示)都不會打開這個旗標,
## 固定 false 時 _process() 直接 return,不影響原本的位置。
var _follow_mouse_centered := false


func _init() -> void:
	# 純視覺元件,不吃滑鼠事件——擋到底下的拖曳來源/放置目標是呼叫端沒設好,
	# 這裡直接預設 IGNORE 才不會每個使用場景都要各自記得設一次。
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_standee_texture = _build_standee_texture()
	_leader_icon_texture = load(GameEnums.LEADER_FLAG_ICON_PATH)
	queue_redraw()


## Godot 的 set_drag_preview() 每一幀會直接把「傳進去的那個 Control 本身」的
## position 蓋成滑鼠座標(實測就算呼叫端自己事先設好 position 想做置中偏移,
## 也一樣會被蓋掉/對不齊實際落點,見 party_edit 的拖曳回報),没辦法在外面
## 用一次性的 position 賦值蓋過去——所以改成每一幀都自己讀滑鼠位置重新算,
## 在 Godot 動手改 position 之後(_process 在輸入事件處理完之後才跑)重新蓋回去,
## 保證畫面上看到的一定是這幀算出來的置中結果。
func _process(_delta: float) -> void:
	if not _follow_mouse_centered:
		return
	global_position = get_global_mouse_position() - size / 2.0


func _update_layout() -> void:
	if battle_cost == null or battle_cost.cells.is_empty():
		custom_minimum_size = Vector2.ZERO
		return

	var min_c := battle_cost.bounds_min()
	var max_c := battle_cost.bounds_max()

	bounds_min = min_c
	custom_minimum_size = Vector2(max_c - min_c + Vector2i.ONE) * cell_size
	size = custom_minimum_size
	queue_redraw()


func _draw() -> void:
	if battle_cost == null:
		return

	var weapon_color := GameEnums.weapon_border_color(weapon)

	for cell in battle_cost.cells:
		var local := Vector2(cell - bounds_min) * cell_size
		var rect := Rect2(local, Vector2(cell_size, cell_size))
		var is_anchor := cell == Vector2i.ZERO
		var alpha := ANCHOR_CELL_FILL_ALPHA if is_anchor else CELL_FILL_ALPHA

		draw_rect(rect, Color(weapon_color.r, weapon_color.g, weapon_color.b, alpha))

	# 站立圖示保留原始比例後(見 _standee_rect())會突出佔位格邊界,可能延伸進
	# 相鄰格子的範圍——放在所有格子填色「之後」畫,確保永遠疊在格子上層,
	# 不會被後畫的鄰接格蓋掉一部分(單一 _draw() 內沒有真的 z_index 概念,
	# 疊層順序就是呼叫順序,所以只能靠畫的先後來保證疊在最上層)。
	if _standee_texture:
		var anchor_rect := Rect2(Vector2(-bounds_min) * cell_size, Vector2(cell_size, cell_size))
		draw_texture_rect(_standee_texture, _standee_rect(anchor_rect), false)
		if is_leader and _leader_icon_texture:
			draw_texture_rect(_leader_icon_texture, _leader_icon_rect(anchor_rect), false)


func _build_standee_texture() -> Texture2D:
	var texture := AtlasTexture.new()
	texture.atlas = load(STANDEE_ATLAS_PATH)
	texture.region = STANDEE_REGION
	return texture


## 佔位格圖示要保留 STANDEE_REGION 原始比例(32x46),不能直接拉伸塞進正方形格子
## 變形——寬度貼齊格子寬、高度依原始比例縮放後置中對齊,人物會比格子稍高一點,
## 跟 Battle 戰場上的角色顯示比例一致(見 battle_unit_visual.gd 的 SPRITE_SCALE
## 等比縮放,不擠壓角色),格子被圖示稍微突出沒關係,不能整隻被壓扁。
func _standee_rect(cell_rect: Rect2) -> Rect2:
	var native_size := STANDEE_REGION.size
	var scaled_height := cell_rect.size.x * (native_size.y / native_size.x)
	var y_offset := (cell_rect.size.y - scaled_height) / 2.0
	return Rect2(
		cell_rect.position + Vector2(0, y_offset),
		Vector2(cell_rect.size.x, scaled_height)
	)


## 隊長圖示疊在佔位格右上角,中心點對齊格子右上角(見 LEADER_ICON_WIDTH_RATIO),
## 效果跟 BattleUnitVisual/BattlePartyRoster 的「掛在角落」badge 一致。
func _leader_icon_rect(cell_rect: Rect2) -> Rect2:
	var icon_size := cell_rect.size.x * LEADER_ICON_WIDTH_RATIO
	var center := cell_rect.position + Vector2(cell_rect.size.x, 0)
	return Rect2(center - Vector2(icon_size, icon_size) / 2.0, Vector2(icon_size, icon_size))


## 建立一個「整體形狀置中對齊游標」的拖曳浮動預覽,給 set_drag_preview() 用。
## 回傳的就是這個 view 本身,呼叫端要保留來後續更新 battle_cost(旋轉)。
static func build_centered_drag_preview(shape: Array[Vector2i], p_cell_size: float, p_weapon: GameEnums.WeaponType = GameEnums.WeaponType.SWORD) -> BattleCostView:
	var view := BattleCostView.new()
	view.cell_size = p_cell_size
	view.weapon = p_weapon
	view.battle_cost = BattleCost.new(shape)
	view._follow_mouse_centered = true
	return view
