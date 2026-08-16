class_name DialogueSpeaker
extends RefCounted

## 對話場景其中一位發言角色的資料:只存 id/顯示名稱/立繪資源路徑/站位(左/右/旁白三選一,
## 見 GameEnums.DialogueSide),比照 Character.face_path 的分工——這裡只存路徑字串,實際
## 載入成 Texture2D 交給 Scenes 層(Scenes/Dialogue/dialogue_box.gd),System 不碰畫面資源
## 載入。旁白(NARRATOR)通常 portrait_path 留空,display_name 也可留空,反正 NARRATOR 不會
## 站左也不會站右,dialogue_box.gd 只會拿它跟 LEFT/RIGHT 比對,兩側自然一起變暗。

var id: String
var display_name: String
var portrait_path: String
var side: GameEnums.DialogueSide

func _init(p_id: String, p_display_name: String, p_portrait_path: String, p_side: GameEnums.DialogueSide) -> void:
	id = p_id
	display_name = p_display_name
	portrait_path = p_portrait_path
	side = p_side
