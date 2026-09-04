class_name MoveEvent
extends BattleEvent

## actor 這次移動的座標紀錄,target 不是移動目的地本身,而是這次移動「相對誰」——
## away=true 時 actor 正在遠離 target(撤退/保持距離),false 時正在靠近(進場攻擊/
## 貼近施法距離),見 MovementPlanner 的呼叫端。path 是完整規劃路徑,to 是實際落腳點,
## 兩者可能不同:最後一步若撞上己方角色所在格,會退回前一步停下(見
## movement_planner.gd 開頭註解),path 仍記錄原本規劃的完整路線供戰報演出用。

var actor: BattleCharacter
var actor_name: String
var target: BattleCharacter
var target_name: String
var from: Vector2i
var path: Array[Vector2i]
var to: Vector2i
var away: bool

func _init(
	p_actor: BattleCharacter, p_target: BattleCharacter,
	p_from: Vector2i, p_path: Array[Vector2i], p_to: Vector2i, p_away: bool,
	p_detail: String = ""
) -> void:
	super._init(GameEnums.BattleEventType.MOVE, p_detail)
	actor = p_actor
	actor_name = p_actor.name
	target = p_target
	target_name = p_target.name
	from = p_from
	path = p_path
	to = p_to
	away = p_away
