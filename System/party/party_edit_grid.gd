class_name PartyEditGrid
extends RefCounted

# =========================================================
# PartyEdit 編成畫面用的網格佔用規則:哪些格子已解鎖、哪個角色
# 佔用哪些格子。PartyEdit 是 Party 底下的一項功能(挑選/擺放
# 組成小隊的角色),所以跟 Party/PartyController 放在同一個資料夾。
#
# 目前沒有共用的網格佔用資料結構可重用(戰鬥格用的是線性掃描
# BattleCharacter.grid_pos),這裡用 Dictionary 另開一份佔用表,範圍
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
var _cell_occupant: Dictionary = {}     # Vector2i -> Character
var _placement_anchor: Dictionary = {}  # Character -> Vector2i
var _placement_shape: Dictionary = {}   # Character -> Array[Vector2i]

## 玩家明確指定的隊長(見 set_leader());null 時 get_leader() 退回「第一個
## 放上來的角色」,呼應 Party.leader 的預設規則(見 Party._init())。
var _leader: Character = null

func _init() -> void:
	for y in range(UNLOCK_ROW_MIN, UNLOCK_ROW_MAX + 1):
		for x in range(UNLOCK_COL_MIN, UNLOCK_COL_MAX + 1):
			_unlocked[Vector2i(x, y)] = true

## 複製一份獨立的網格狀態快照(PartyStore 存「按下完成編輯當下」的版本用,
## 跟畫面上正在編輯、尚未確定的草稿分開,避免草稿中途的每一步操作都直接
## 反映到其他場景讀得到的 STORE 資料)。Dictionary.duplicate() 淺拷貝即可,
## key/value 都是 Vector2i 或 Character 參照,不需要深拷貝角色本身。
func clone() -> PartyEditGrid:
	var copy := PartyEditGrid.new()
	copy._unlocked = _unlocked.duplicate()
	copy._cell_occupant = _cell_occupant.duplicate()
	copy._placement_anchor = _placement_anchor.duplicate()
	copy._placement_shape = _placement_shape.duplicate()
	copy._leader = _leader
	return copy

## 存檔/讀檔用(見 Scripts/save_data_codec.gd):目前解鎖的格子清單,不含預設 4x4 以外
## 由 unlock_random_locked_cell() 額外解鎖的格子也要一併存起來,重開遊戲不能被重置回
## 預設解鎖範圍。
func get_unlocked_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	cells.assign(_unlocked.keys())
	return cells

## 存檔/讀檔用:依存檔資料補上額外解鎖的格子(不會取消已經解鎖的預設 4x4,直接聯集)。
func unlock_cells(cells: Array[Vector2i]) -> void:
	for cell in cells:
		_unlocked[cell] = true

func is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < GRID_COLS and cell.y >= 0 and cell.y < GRID_ROWS

func is_unlocked(cell: Vector2i) -> bool:
	return _unlocked.has(cell)

func get_character_at(cell: Vector2i) -> Character:
	return _cell_occupant.get(cell)

func is_placed(character: Character) -> bool:
	return _placement_anchor.has(character)

func get_all_placed_characteres() -> Array:
	return _placement_anchor.keys()

func get_placement_anchor(character: Character) -> Vector2i:
	return _placement_anchor.get(character, Vector2i.ZERO)

func get_placement_shape(character: Character) -> Array[Vector2i]:
	return _placement_shape.get(character, [])

## excluding_character:移動自己已放置的角色時,傳入自己,讓自己目前佔用的格子
## 不會被判定成「被別人佔用」
func can_place(shape: Array[Vector2i], anchor: Vector2i, excluding_character: Character = null) -> bool:
	for offset in shape:
		var cell := anchor + offset
		if not is_in_bounds(cell) or not is_unlocked(cell):
			return false
		var occupant: Character = _cell_occupant.get(cell)
		if occupant != null and occupant != excluding_character:
			return false
	return true

## 已派駐根據地生產的角色也可以放上小隊網格——呼叫端(Scenes/PartyEdit/
## party_edit_availability_layer.gd 的 _drop_data())要先跳 ConfirmDialog 問玩家是否把人從
## 原本的建築召回,確定才呼叫 BaseDispatchStore.undispatch_character() 再放這裡,這裡本身
## 不擋、也不負責召回(佔用規則以外的事一律留給 Scenes 層),跟 BaseDispatchStore.dispatch()
## 允許把小隊成員(非隊長)改派去工作是同一組雙向轉換,不再是完全互斥。
func place(character: Character, shape: Array[Vector2i], anchor: Vector2i) -> bool:
	if not can_place(shape, anchor, character):
		return false
	if is_placed(character):
		remove(character)
	for offset in shape:
		_cell_occupant[anchor + offset] = character
	_placement_anchor[character] = anchor
	_placement_shape[character] = shape.duplicate()
	return true

func remove(character: Character) -> void:
	if not is_placed(character):
		return
	var anchor: Vector2i = _placement_anchor[character]
	for offset in _placement_shape[character]:
		_cell_occupant.erase(anchor + offset)
	_placement_anchor.erase(character)
	_placement_shape.erase(character)
	if character == _leader:
		_leader = null

## 找出離「靠左、垂直置中」目標格最近的合法擺放位置,只在解鎖區內找,用曼哈頓
## 距離排序;找不到任何合法擺放時回傳 Vector2i(-1, -1)。給尚未經玩家手動編輯過的
## 初始擺盤用(見 main.gd 的 _ensure_starting_party()),不管形狀多大/多不規則
## 都能找到最貼近「靠左置中」語意的位置,而不是死板寫死一個格子、遇到形狀擺不下
## 就整個放置失敗。
func find_leaning_left_anchor(shape: Array[Vector2i]) -> Vector2i:
	var target := Vector2i(UNLOCK_COL_MIN, roundi((UNLOCK_ROW_MIN + UNLOCK_ROW_MAX) / 2.0))
	var best := Vector2i(-1, -1)
	var best_dist := -1
	for y in range(UNLOCK_ROW_MIN, UNLOCK_ROW_MAX + 1):
		for x in range(UNLOCK_COL_MIN, UNLOCK_COL_MAX + 1):
			var anchor := Vector2i(x, y)
			if not can_place(shape, anchor):
				continue
			var dist := absi(anchor.x - target.x) + absi(anchor.y - target.y)
			if best_dist == -1 or dist < best_dist:
				best = anchor
				best_dist = dist
	return best

## 明確指定隊長;只有已放置的角色才能被設為隊長。
func set_leader(character: Character) -> void:
	if is_placed(character):
		_leader = character

## 目前隊長:有明確指定且仍在場上就回傳那一位,否則退回「第一個放上來的
## 角色」(呼應 Party.leader 的預設規則),沒有任何角色放上場則回傳 null。
func get_leader() -> Character:
	if _leader != null and is_placed(_leader):
		return _leader
	var placed := get_all_placed_characteres()
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
