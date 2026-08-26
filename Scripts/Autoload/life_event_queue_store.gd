extends Node

# =========================================================
# 新生兒命名 + 留學國家決定畫面(Scenes/LifeEvent/life_event_scene.gd)的排隊播放器
# (autoload,見 project.godot)。System/time/world_time_event_library.gd 的
# _deliver_child() 是唯一觸發點——同一個月可能同時有好幾個小孩出生,場景一次只能顯示
# 一個小孩,用 _pending 佇列 + _busy 旗標讓他們排隊逐一顯示,不會互相搶著切場景。
#
# 第一個小孩用 NavigationStore.go_to() 切過去(場景沒有 HeaderBar,世界時間自動停止
# 推進,比照 CLAUDE.md「世界時間」章節的既有慣例,不用另外手動暫停);同一批還有下一個
# 小孩時改用 get_tree().reload_current_scene() 原地換下一個小孩的資料重新整理畫面,
# 不會多推一層 NavigationStore 歷史;全部處理完才呼叫 NavigationStore.go_back() 回到
# 觸發當下玩家原本所在的場景。
# =========================================================

const SCENE_PATH := "res://Scenes/LifeEvent/life_event_scene.tscn"
const MAILBOX_KEY := "life_event_character"

var _pending: Array[Character] = []
var _busy: bool = false


func queue_child(character: Character) -> void:
	_pending.append(character)
	if not _busy:
		_busy = true
		SceneHandoffStore.queue(MAILBOX_KEY, _pending.pop_front())
		NavigationStore.go_to(SCENE_PATH)


## life_event_scene.gd 確認完目前這個小孩後呼叫:還有排隊中的小孩就原地換下一個
## 重來一輪,沒有了才真正離開這個場景。
func finish_current() -> void:
	if _pending.is_empty():
		_busy = false
		NavigationStore.go_back()
		return
	SceneHandoffStore.queue(MAILBOX_KEY, _pending.pop_front())
	get_tree().reload_current_scene()
