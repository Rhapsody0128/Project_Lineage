class_name PartyEditGrid
extends RefCounted

# =========================================================
# PartyEdit 編成畫面用的網格佔用規則:哪些格子已解鎖、哪個角色
# 佔用哪些格子。PartyEdit 是 Party 底下的一項功能(挑選/擺放
# 組成小隊的角色),所以跟 Party/PartyController 放在同一個資料夾。
#
# 目前沒有共用的網格佔用資料結構可重用(戰鬥格用的是線性掃描
# BattleHero.grid_pos),這裡用 Dictionary 另開一份佔用表,範圍
# 限定在這個新功能裡,不影響既有戰鬥系統。
#
# 編成畫面只顯示/管理玩家自己這一方的 6x6——不需要呈現敵方那半的戰場。
# 座標系跟 Battle 的自身區(x:0~5, y:0~5)同一套,所以角色在這裡的站位
# (見 _placement_anchor)可以直接原樣當成 Battle 開戰時的初始 grid_pos
# 使用(見 Party.battle_cost_positions / battle.gd 的 _deploy_side())。
# =========================================================

const GRID_COLS := 6
const GRID_ROWS := 6
## 預設解鎖 4x4:列(y)置中(0-indexed 第 1~4 列),欄(x)靠左(0-indexed 第 0~3 欄)
const UNLOCK_ROW_MIN := 1
const UNLOCK_ROW_MAX := 4
const UNLOCK_COL_MIN := 0
const UNLOCK_COL_MAX := 3

var _unlocked: Dictionary = {}          # Vector2i -> true
var _cell_occupant: Dictionary = {}     # Vector2i -> Hero
var _placement_anchor: Dictionary = {}  # Hero -> Vector2i
var _placement_shape: Dictionary = {}   # Hero -> Array[Vector2i]

## 玩家明確指定的隊長(見 set_leader());null 時 get_leader() 退回「第一個
## 放上來的角色」,呼應 Party.leader 的預設規則(見 Party._init())。
var _leader: Hero = null

func _init() -> void:
	for y in range(UNLOCK_ROW_MIN, UNLOCK_ROW_MAX + 1):
		for x in range(UNLOCK_COL_MIN, UNLOCK_COL_MAX + 1):
			_unlocked[Vector2i(x, y)] = true

## 複製一份獨立的網格狀態快照(PartyEditStore 存「按下完成編輯當下」的版本用,
## 跟畫面上正在編輯、尚未確定的草稿分開,避免草稿中途的每一步操作都直接
## 反映到其他場景讀得到的 STORE 資料)。Dictionary.duplicate() 淺拷貝即可,
## key/value 都是 Vector2i 或 Hero 參照,不需要深拷貝角色本身。
func clone() -> PartyEditGrid:
	var copy := PartyEditGrid.new()
	copy._unlocked = _unlocked.duplicate()
	copy._cell_occupant = _cell_occupant.duplicate()
	copy._placement_anchor = _placement_anchor.duplicate()
	copy._placement_shape = _placement_shape.duplicate()
	copy._leader = _leader
	return copy

func is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < GRID_COLS and cell.y >= 0 and cell.y < GRID_ROWS

func is_unlocked(cell: Vector2i) -> bool:
	return _unlocked.has(cell)

func get_hero_at(cell: Vector2i) -> Hero:
	return _cell_occupant.get(cell)

func is_placed(hero: Hero) -> bool:
	return _placement_anchor.has(hero)

func get_all_placed_heroes() -> Array:
	return _placement_anchor.keys()

func get_placement_anchor(hero: Hero) -> Vector2i:
	return _placement_anchor.get(hero, Vector2i.ZERO)

func get_placement_shape(hero: Hero) -> Array[Vector2i]:
	return _placement_shape.get(hero, [])

## excluding_hero:移動自己已放置的角色時,傳入自己,讓自己目前佔用的格子
## 不會被判定成「被別人佔用」
func can_place(shape: Array[Vector2i], anchor: Vector2i, excluding_hero: Hero = null) -> bool:
	for offset in shape:
		var cell := anchor + offset
		if not is_in_bounds(cell) or not is_unlocked(cell):
			return false
		var occupant: Hero = _cell_occupant.get(cell)
		if occupant != null and occupant != excluding_hero:
			return false
	return true

func place(hero: Hero, shape: Array[Vector2i], anchor: Vector2i) -> bool:
	if not can_place(shape, anchor, hero):
		return false
	if is_placed(hero):
		remove(hero)
	for offset in shape:
		_cell_occupant[anchor + offset] = hero
	_placement_anchor[hero] = anchor
	_placement_shape[hero] = shape.duplicate()
	return true

func remove(hero: Hero) -> void:
	if not is_placed(hero):
		return
	var anchor: Vector2i = _placement_anchor[hero]
	for offset in _placement_shape[hero]:
		_cell_occupant.erase(anchor + offset)
	_placement_anchor.erase(hero)
	_placement_shape.erase(hero)
	if hero == _leader:
		_leader = null

## 明確指定隊長;只有已放置的角色才能被設為隊長。
func set_leader(hero: Hero) -> void:
	if is_placed(hero):
		_leader = hero

## 目前隊長:有明確指定且仍在場上就回傳那一位,否則退回「第一個放上來的
## 角色」(呼應 Party.leader 的預設規則),沒有任何角色放上場則回傳 null。
func get_leader() -> Hero:
	if _leader != null and is_placed(_leader):
		return _leader
	var placed := get_all_placed_heroes()
	return placed[0] if not placed.is_empty() else null

## 隨機解鎖一格目前反灰(未解鎖)的格子,回傳解鎖的格子座標;
## 沒有反灰格可解鎖時回傳 Vector2i(-1,-1)
func unlock_random_locked_cell() -> Vector2i:
	var locked: Array[Vector2i] = []
	for y in range(GRID_ROWS):
		for x in range(GRID_COLS):
			var cell := Vector2i(x, y)
			if not is_unlocked(cell):
				locked.append(cell)
	if locked.is_empty():
		return Vector2i(-1, -1)
	var chosen: Vector2i = Util.get_random_from_array(locked)
	_unlocked[chosen] = true
	return chosen
