class_name MarriageRule
extends RefCounted

## 判斷 self_character 能不能向 target_character 告白:性別要相反(目前只有
## MALE/FEMALE 兩種),雙方都要未婚(mate == null,呼應企劃「一生只能結一次婚」規則)。
static func can_propose(self_character: Character, target_character: Character) -> bool:
	return (
		self_character.mate == null
		and target_character.mate == null
		and self_character.gender != target_character.gender
	)


## 告白成功率:玩家選的角色正是對方屬意的 intended_target 時 100% 接受,選了其他人
## (等於是拿別人去反告白,不是對方原本想要的人)只有 20%——見
## System/event/town/town_tavern_event.gd 的告白後續分支,沒骰中就是真的告白失敗,
## 沒有補骰的餘地。
static func acceptance_chance(picked_character: Character, intended_target: Character) -> float:
	return 100.0 if picked_character == intended_target else 20.0


## 依 acceptance_chance() 骰一次,回傳這次告白是否成功。
static func roll_acceptance(picked_character: Character, intended_target: Character) -> bool:
	return Util.get_random_float(0.0, 100.0) < acceptance_chance(picked_character, intended_target)
