class_name RoamingEnemyVisual
extends Node2D

## 大地圖上單一 RoamingEnemy 的畫面呈現:比照 MapObjectVisual 純顯示、不做點擊/命中判定
## (走近觸發交給 map.gd 每幀算距離,見 RoamingEnemySpawner.VISION_RADIUS/is_visible_to_player)。
## 外觀直接沿用戰鬥敵人的既有慣例——PlayerAvatar 同一份 Images/Warrier/animated_sprite_2d.tscn
## 加上 BattleUnitVisual.ENEMY_TINT 紅色調,不重複定義顏色常數或另外準備美術。

const CHARACTER_SCENE_PATH := "res://Images/Warrier/animated_sprite_2d.tscn"
## 位移小於這個長度視為「沒有在走」,播 idle 而不是 walk 動畫(比照 map.gd 的
## _update_player_visual() 判斷)。
const MOVE_EPSILON := 0.5

## 評分標籤位置:貼著 sprite(38x46,AnimatedSprite2D 預設置中)右下角。
const RANK_BADGE_OFFSET := Vector2(14, 16)

## 城鎮/城堡是 map.tscn 裡手動擺放、z_index 預設 0 的場景節點,遊蕩者要蓋在它們上面
## 才不會被地標擋住,所以給正值。
const ENEMY_Z_INDEX := 1

var enemy: RoamingEnemy
var sprite: AnimatedSprite2D
var _last_dir_name := "Down"
## 上一次 update_visual() 同步時的位置,跟目前 enemy.position 相減即可得到這一幀的
## 位移量——不需要 RoamingEnemySpawner/map.gd 額外把 advance_wander() 的回傳值一路傳進來。
var _last_synced_position: Vector2


func setup(p_enemy: RoamingEnemy) -> void:
	enemy = p_enemy
	position = enemy.position
	_last_synced_position = enemy.position
	z_index = ENEMY_Z_INDEX

	var scene := load(CHARACTER_SCENE_PATH) as PackedScene
	sprite = scene.instantiate()
	add_child(sprite)
	sprite.modulate = BattleUnitVisual.ENEMY_TINT
	sprite.play("idle_Down")

	_add_rank_badge()


## 敵人評分:右下角一個小文字標籤,目前一律顯示 GameEnums.RankType.E
## (見 RoamingEnemySpawner._try_spawn_in_cell()),之後有真正的評分公式再擴充。
func _add_rank_badge() -> void:
	var label := Label.new()
	label.text = GameEnums.rank_label(enemy.rank)
	label.position = RANK_BADGE_OFFSET
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)


## map.gd 每幀呼叫:同步位置、依這一幀的位移量播 idle/walk 動畫。
func update_visual() -> void:
	var move_delta := enemy.position - _last_synced_position
	_last_synced_position = enemy.position
	position = enemy.position

	if move_delta.length() < MOVE_EPSILON:
		sprite.play("idle_%s" % _last_dir_name)
		return

	var dir_name := _dir_name(move_delta)
	_last_dir_name = dir_name
	sprite.play("walk_%s" % dir_name)


## 朝向優先序沿用 Scenes/Map/map.gd 與 Scenes/Battle/battle_unit_visual.gd 的既有慣例:
## x 軸優先於 y 軸,動畫名稱是 "Top" 不是 "Up"。
func _dir_name(dir: Vector2) -> String:
	if dir.x > 0:
		return "Right"
	elif dir.x < 0:
		return "Left"
	elif dir.y > 0:
		return "Down"
	elif dir.y < 0:
		return "Top"
	return "Down"
