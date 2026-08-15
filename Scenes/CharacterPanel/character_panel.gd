extends CanvasLayer

# =========================================================
# 全域共用的角色資料面板(以 autoload 掛載於 project.godot,
# 任何場景呼叫 CharacterPanel.open_for_hero(hero) 即可彈出,
# 不屬於任何單一場景;右上角叉叉鍵關閉)。
# 只是彈出式對話框外殼(背景遮罩 + 標題列 + 關閉鍵),實際資料
# 呈現轉發給 CharacterDetailView——CharacterRoster 場景也內嵌
# 同一顆元件(非彈出式),兩處共用同一份呈現邏輯。
# =========================================================

@onready var root: Control = $Root
@onready var detail_view: CharacterDetailView = $Root/CenterContainer/PanelBox/Margin/Content/DetailView


func _ready() -> void:
	root.visible = false


## 任何場景都可呼叫:CharacterPanel.open_for_hero(hero)。battle_hero 是選填的
## ——從戰鬥場景點頭像開啟時會多帶這個(見 battle_party_roster.gd),讓雷達圖能
## 額外顯示套用完戰場加成(暴擊/被動/buff/debuff)的即時數值,且隨戰況連動更新;
## 非戰鬥情境(創角面板等)留空即可,雷達圖只顯示基礎潛力數字。
func open_for_hero(hero: Hero, battle_hero: BattleHero = null) -> void:
	if hero == null:
		return
	detail_view.set_hero(hero, battle_hero)
	root.visible = true


func close() -> void:
	root.visible = false
	# 面板關閉後停止雷達圖的逐幀重繪(見 CharacterPotentialRadar._process()),
	# 不然戰鬥中即使面板關著,還是會白白每幀重繪一個沒人在看的節點。
	detail_view.set_hero(null)
