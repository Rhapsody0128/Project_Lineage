class_name MarriageCandidateList
extends VBoxContainer

# =========================================================
# 城鎮中心聯姻候選人盲選清單——只顯示姓名/年齡,不用 CharacterDetailView 那套完整情報選人
# 畫面(呼應玩家角色本人「還沒真的認識這些候選人」的敘事:國家寄回的介紹信只會提名字
# 年紀,不會附完整素質/血統/家族資料),跟酒館告白/根據地派遣等「看得到完整情報」的選人
# 情境刻意不同。塞進 Scripts/UI/fullscreen_overlay.gd 的 FullscreenOverlay 顯示(見
# System/event/base/base_marriage_event.gd 的 _open_candidate_picker()),不是獨立場景。
#
# 只有兩個結果:candidate_picked(candidate) 選了某位候選人;declined() 都不合適(呼叫端的
# FullscreenOverlay × 鈕也接到同一個 declined 處理,見呼叫端寫法)——兩者是完全不同的收尾
# 分支(前者接候選人反應 Dialogue,後者直接播聯姻角色婉拒獨白),呼叫端不要合併成同一個
# callback 用 null 判斷。
# =========================================================

signal candidate_picked(candidate: Character)
signal declined()

const AVATAR_SIZE := Vector2(64, 64)

var _list: VBoxContainer


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 16)

	var hint := Label.new()
	hint.text = "只有姓名與年齡的介紹信,詳細資料要見面後才知道。"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	hint.add_theme_color_override("font_color", UiStyle.PARCHMENT_SUBTITLE_COLOR)
	add_child(hint)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 10)
	add_child(_list)

	var decline_button := Button.new()
	decline_button.text = "都沒有中意的人選"
	UiStyle.apply_wood_plaque_button(decline_button, 16.0, 8.0)
	decline_button.add_theme_font_size_override("font_size", 16)
	decline_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	decline_button.pressed.connect(func() -> void: declined.emit())
	add_child(decline_button)


func setup(candidates: Array[Character]) -> void:
	for candidate in candidates:
		_list.add_child(_build_row(candidate))


func _build_row(candidate: Character) -> Control:
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", UiStyle.parchment_row_style(UiStyle.PARCHMENT_ROW_BORDER, 1, 12, 16.0, 10.0, 6))

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	row.add_child(hbox)

	var face := TextureRect.new()
	face.custom_minimum_size = AVATAR_SIZE
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_SCALE
	if not candidate.face_path.is_empty():
		face.texture = load(candidate.face_path) as Texture2D
	hbox.add_child(face)

	var label := Label.new()
	label.text = "%s　%d 歲" % [candidate.full_name, candidate.age]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", UiStyle.PARCHMENT_TEXT_COLOR)
	hbox.add_child(label)

	var button := Button.new()
	button.text = "選擇"
	UiStyle.apply_wood_plaque_button(button, 16.0, 6.0)
	button.add_theme_font_size_override("font_size", 16)
	button.pressed.connect(func() -> void: candidate_picked.emit(candidate))
	hbox.add_child(button)

	return row
