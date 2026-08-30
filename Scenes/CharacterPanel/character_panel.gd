extends CanvasLayer

# =========================================================
# 全域共用的角色資料面板(以 autoload 掛載於 project.godot,
# 任何場景呼叫 CharacterPanel.open_for_character(character) 即可彈出,
# 不屬於任何單一場景;右上角叉叉鍵關閉)。
# 只是彈出式對話框外殼(背景遮罩 + 標題列 + 關閉鍵),實際資料
# 呈現轉發給 CharacterDetailView——CharacterRoster 場景也內嵌
# 同一顆元件(非彈出式),兩處共用同一份呈現邏輯。
# =========================================================

@onready var root: Control = $Root
@onready var dim_bg: ColorRect = $Root/DimBg
@onready var panel_box: PanelContainer = $Root/CenterContainer/PanelBox
@onready var close_button: Button = $Root/CenterContainer/PanelBox/Content/TopBar/CloseButton
@onready var detail_view: CharacterDetailView = $Root/CenterContainer/PanelBox/Content/DetailView


func _ready() -> void:
	root.visible = false
	# 彈出面板姓名區只顯示 given name,不顯示姓氏(見使用者需求)——CharacterRoster 等
	# 其餘嵌用 CharacterDetailView 的地方維持預設全名顯示,只有這顆彈出面板要收斂成
	# 只顯示名字,在第一次 open_for_character() 呼叫 set_character() 之前設好即可。
	detail_view.name_only = true
	# PanelBox 擋在 DimBg 之上,點面板內容不會傳到這裡;只有點面板外的遮罩區域才會觸發。
	dim_bg.gui_input.connect(_on_dim_bg_gui_input)
	# PanelBox 的寬度來自子節點 DetailView 自己宣告的 custom_minimum_size.x
	# (CharacterDetailView.PANEL_WIDTH),高度來自 character_panel.tscn 寫死在 PanelBox 上
	# 的 custom_minimum_size.y——用 get_combined_minimum_size() 現場問出這個「已經確定、
	# 不用猜」的尺寸當第一次套用值,面板還沒顯示過也能立刻套對羊皮紙裁切比例,不用賭
	# resized 訊號會不會在打開前就先觸發過(root 這裡預設隱藏,傳 0,0 會直接跳過套用,
	# 開啟時可能整個沒有背景樣式)。
	var panel_size := panel_box.get_combined_minimum_size()
	UiStyle.apply_parchment_panel(panel_box, panel_size.x, panel_size.y)
	UiStyle.apply_wood_plaque_button(close_button, 10.0, 4.0)
	close_button.add_theme_font_size_override("font_size", 18)


## 任何場景都可呼叫:CharacterPanel.open_for_character(character)。battle_character 是選填的
## ——從戰鬥場景點頭像開啟時會多帶這個(見 battle_party_roster.gd),讓雷達圖能
## 額外顯示套用完戰場加成(暴擊/被動/buff/debuff)的即時數值,且隨戰況連動更新;
## 非戰鬥情境(創角面板等)留空即可,雷達圖只顯示基礎潛力數字。
func open_for_character(character: Character, battle_character: BattleCharacter = null) -> void:
	if character == null:
		return
	detail_view.set_character(character, battle_character)
	root.visible = true


func _on_dim_bg_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close()


func close() -> void:
	root.visible = false
	# 面板關閉後停止雷達圖的逐幀重繪(見 CharacterPotentialRadar._process()),
	# 不然戰鬥中即使面板關著,還是會白白每幀重繪一個沒人在看的節點。
	detail_view.set_character(null)
