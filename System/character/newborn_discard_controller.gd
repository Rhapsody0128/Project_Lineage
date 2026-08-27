class_name NewbornDiscardController
extends RefCounted

## 新生兒命名畫面「丟棄」的唯一入口(見 Scenes/LifeEvent/life_event_scene.gd)。孩子在
## WorldTimeEventLibrary._deliver_child() 出生當下就已經 give_birth() 寫入親子關係、
## register 進 AllCharacterStore(見 CLAUDE.md「新生兒命名與留學」)——丟棄要把這些痕跡
## 完全清乾淨,跟 CharacterDeathController.kill() 的死亡標記不同:死亡角色仍要留在祖譜
## (靠 is_dead 加註「已故」),丟棄則是玩家反悔取消出生,不能出現在祖譜、也不能進角色池,
## 所以直接砍掉親子關係參照 + 從 AllCharacterStore 移除,而不是標記旗標。

static func discard(child: Character) -> void:
	for parent_character in child.parent:
		parent_character.children.erase(child)
	child.parent = []
	AllCharacterStore.all_characteres.erase(child)
	MoraleStore.record_event("放棄新生兒", MoraleStore.DISCARD_CHILD_DELTA)
