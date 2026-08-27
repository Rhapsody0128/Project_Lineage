class_name BattleUltimatePanel
extends PanelContainer

# =========================================================
# 即時戰鬥模式(Scenes/Battle/battle.gd 的 _run_battle_realtime())專用:board 下方的
# 奧義施放面板。純粹畫面表現+輸入轉發——按下奧義按鈕只發出 ultimate_selected 訊號,
# 實際能不能放/放了會發生什麼事一律交給 System 層(Battle.cast_ultimate()),這裡不
# 判斷、不寫規則,呼應 CLAUDE.md「System 管邏輯,Scenes 管畫面」。
#
# 不會逐回合暫停詢問——面板從戰鬥開始就一直開著,戰鬥照樣自動連續播放,玩家隨時想放
# 就直接按(還放得出來的話),按下去只是把這次施放排進佇列,下一回合開始才生效
# (見 Ultimate.delay_rounds/Battle.cast_ultimate()),不影響戰鬥本身的播放節奏。
#
# 最多可能同時有 18 個奧義(祭壇 9 個「祝福」+ 禁忌祭壇 9 個「災厄」),擠在同一列會爆版,
# 所以依 Ultimate.category(GameEnums.UltimateCategory)分兩列呈現,各自最多 9 個。
# =========================================================

signal ultimate_selected(ultimate: Ultimate)

@onready var blessing_button_row: HBoxContainer = $VBox/BlessingRow/BlessingButtonRow
@onready var calamity_button_row: HBoxContainer = $VBox/CalamityRow/CalamityButtonRow

const BUTTON_SIZE := Vector2(112, 22)
const BUTTON_FONT_SIZE := 12

var _buttons: Dictionary = {} # Ultimate -> Button


## 依可施放的奧義清單建立按鈕,只在戰鬥一開始呼叫一次(清單本身不會在戰鬥中變動,
## 變的只是「還能不能放」,見 refresh_button())。面板貼在戰場下緣一條窄帶(跟左右
## 頭像列、BoardCanvas/UnitsLayer 一起收在 battle.tscn 的 BattlefieldPanel 底下),
## 寬度由 battle.gd 的 _apply_log_layout() 隨戰場縮放同步調整、左緣固定貼齊戰場左緣,
## 按鈕尺寸配合這條窄帶縮小。依 ultimate.category 分別塞進「祝福」/「災厄」兩列。
func setup(ultimates: Array[Ultimate]) -> void:
	for row in [blessing_button_row, calamity_button_row]:
		for child in row.get_children():
			child.queue_free()
	_buttons.clear()

	for ultimate in ultimates:
		var row := calamity_button_row if ultimate.category == GameEnums.UltimateCategory.CALAMITY else blessing_button_row
		var button := Button.new()
		button.custom_minimum_size = BUTTON_SIZE
		button.add_theme_font_size_override("font_size", BUTTON_FONT_SIZE)
		button.text = ultimate.name
		button.tooltip_text = ultimate.description
		button.pressed.connect(_on_ultimate_button_pressed.bind(ultimate))
		row.add_child(button)
		_buttons[ultimate] = button


## 依目前是否還放得出來(battle.gd 同時檢查 Battle.can_cast_ultimate() 這場戰鬥內的
## 次數與 UltimateStore.can_use() 跨場景保留的全程次數)+ 還剩幾次(UltimateStore.
## uses_remaining(),該奧義跨場景共用、5 次用完就沒了)更新單一按鈕的可按狀態與文字。
func refresh_button(ultimate: Ultimate, can_cast: bool, uses_remaining: int) -> void:
	var button: Button = _buttons.get(ultimate)
	if button == null:
		return
	button.disabled = not can_cast
	button.text = "%s (%d)" % [ultimate.name, uses_remaining]


func open_cast_window() -> void:
	visible = true


func close_cast_window() -> void:
	visible = false


func _on_ultimate_button_pressed(ultimate: Ultimate) -> void:
	ultimate_selected.emit(ultimate)
