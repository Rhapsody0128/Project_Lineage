extends Control

## 獨立的對話場景(不是疊加在別的場景上的 overlay)。播放內容跟播完之後要去哪個
## 場景,由呼叫端透過 System/event/location_event.gd 的 goto_dialogue() 存進
## SceneHandoffStore(key 是 LocationEvent.DIALOGUE_MAILBOX_KEY)、再 change_scene_to_file
## 過來,這裡的 _ready() 直接讀出來播放。「誰在說話」「這一句
## 該顯示哪一側的頭像」全部轉發給 Dialogue(見 System/dialogue/dialogue.gd)判定,
## 這裡只負責把資料轉成畫面呈現——頭像單純顯示 Character.face_path 那張圖,沒有講過話
## 的那一側直接隱藏(不留空框);已經講過但目前不是輪到他的那一側蓋灰色遮罩,
## 對比出「這是上一句講話的人」。旁白(GameEnums.DialogueSide.NARRATOR)講話時不屬於
## LEFT 也不屬於 RIGHT,is_speaking(LEFT)/is_speaking(RIGHT) 自然都回傳 false,兩側頭像
## (如果先前露過臉)會一起蓋上遮罩變暗,不用額外分支處理。
##
## 操作方式:畫面上點一下(ClickCatcher 蓋住全螢幕)就推進下一句,播完最後一句(或
## 呼叫端根本沒塞資料)先執行呼叫端選填的 on_finished、再自動切去 next_scene_path(留空
## 就不轉場,見 _leave())。遇到選擇題(DialogueLine.has_choices)改成顯示選項按鈕、讓
## ClickCatcher 讓開,玩家只能靠選按鈕離開這句,見 _refresh_choices()。

@onready var background: TextureRect = $Background
@onready var left_portrait: TextureRect = $LeftPortraitFrame
@onready var left_mask: ColorRect = $LeftPortraitFrame/LeftGrayMask
@onready var right_portrait: TextureRect = $RightPortraitFrame
@onready var right_mask: ColorRect = $RightPortraitFrame/RightGrayMask
@onready var text_box: PanelContainer = $TextBox
@onready var speaker_name_label: Label = $TextBox/Margin/Content/SpeakerNameLabel
@onready var dialogue_label: Label = $TextBox/Margin/Content/DialogueLabel
@onready var choices_container: VBoxContainer = $TextBox/Margin/Content/ChoicesContainer
@onready var click_catcher: Control = $ClickCatcher

var dialogue: Dialogue = null
var _next_scene_path: String = ""
## 對話播完時執行一次的選填 callback,見 LocationEvent.goto_dialogue() 的 on_finished
## 參數——不是每段對話都會用到,大多數留空(Callable() 無效,_leave() 直接跳過)。
var _on_finished: Callable = Callable()


func _ready() -> void:
	UiStyle.apply_parchment_panel(text_box, 1520.0, 180.0)
	click_catcher.gui_input.connect(_on_click_catcher_gui_input)

	# peek() 不清空——DialogueLine.choices 裡可能嵌著捕捉呼叫端 self 的 lambda,提早
	# 清掉這份參照會讓 RefCounted 事件物件提早被釋放(見 SceneHandoffStore 的註解)。
	var handoff := SceneHandoffStore.peek(LocationEvent.DIALOGUE_MAILBOX_KEY)
	dialogue = handoff.payload as Dialogue if handoff != null else null
	_next_scene_path = handoff.next_scene_path if handoff != null else ""
	_on_finished = handoff.result_callback if handoff != null else Callable()

	if dialogue == null or dialogue.lines.is_empty():
		# 防呆:不是從 LocationEvent.goto_dialogue() 的正常流程進來(例如直接開這個場景測試)。
		_leave()
		return

	background.texture = load(dialogue.background_path) as Texture2D if not dialogue.background_path.is_empty() else null

	dialogue.current_index = 0
	_refresh()


func _on_click_catcher_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_advance()


func _advance() -> void:
	if dialogue == null:
		return
	if not dialogue.advance():
		_leave()
		return
	_refresh()


## 播完(或沒資料可播)後先執行呼叫端的 on_finished(見 LocationEvent.goto_dialogue()),
## 再切去事先指定好的下一個場景;next_scene_path 留空時只執行 on_finished、留在目前這個
## 對話畫面上不轉場(例如 TownTavernEvent 的酒館老闆招呼詞播完直接疊加彈出 ActionPanel)。
## 清空後才呼叫,避免 callback 內又觸發一次 _leave() 時重複執行。
func _leave() -> void:
	var callback := _on_finished
	_on_finished = Callable()
	if callback.is_valid():
		callback.call()

	if _next_scene_path.is_empty():
		return
	var error := get_tree().change_scene_to_file(_next_scene_path)
	if error != OK:
		printerr("Error changing scene from dialogue: ", error)


func _refresh() -> void:
	var line := dialogue.current_line
	if line == null:
		return

	var speaker := dialogue.current_speaker()
	speaker_name_label.text = speaker.display_name if speaker != null else ""
	dialogue_label.text = line.text

	left_portrait.texture = _load_portrait(dialogue.current_speaker_for_side(GameEnums.DialogueSide.LEFT))
	right_portrait.texture = _load_portrait(dialogue.current_speaker_for_side(GameEnums.DialogueSide.RIGHT))

	# 這側還沒有人講過話(頭像是 null)就整個隱藏,不要留一格空框。
	left_portrait.visible = left_portrait.texture != null
	right_portrait.visible = right_portrait.texture != null

	# 有頭像但目前不是輪到他講話的那一側蓋灰色遮罩,對比出正在說話的人;
	# 沒頭像(整格隱藏)的那一側遮罩自然也不會顯示。
	left_mask.visible = left_portrait.visible and not dialogue.is_speaking(GameEnums.DialogueSide.LEFT)
	right_mask.visible = right_portrait.visible and not dialogue.is_speaking(GameEnums.DialogueSide.RIGHT)

	_refresh_choices(line)


## 選擇題:清掉上一次的選項按鈕、依 line.choices 重新生成。ClickCatcher 蓋滿全螢幕,
## 不讓開的話會擋掉選項按鈕的點擊,所以選擇題時要隱藏它,玩家只能靠選項按鈕離開
## 這句,不能單靠點畫面推進。
func _refresh_choices(line: DialogueLine) -> void:
	for child in choices_container.get_children():
		child.queue_free()

	choices_container.visible = line.has_choices
	click_catcher.visible = not line.has_choices

	for choice in line.choices:
		var button := Button.new()
		button.text = choice.label
		button.pressed.connect(_on_choice_pressed.bind(choice))
		choices_container.add_child(button)


func _on_choice_pressed(choice: DialogueChoice) -> void:
	if choice.on_selected.is_valid():
		choice.on_selected.call()
	if choice.next_scene_path.is_empty():
		return
	var error := get_tree().change_scene_to_file(choice.next_scene_path)
	if error != OK:
		printerr("Error changing scene from dialogue choice: ", error)


func _load_portrait(speaker: DialogueSpeaker) -> Texture2D:
	if speaker == null or speaker.portrait_path.is_empty():
		return null
	return load(speaker.portrait_path) as Texture2D
