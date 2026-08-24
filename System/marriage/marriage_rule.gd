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


## 聯姻候選發起人清單:未婚(mate == null)且未禁用的角色——呼應 can_propose() 的前提之一
## (性別互斥要等挑到對象後才判定,這裡先篩單邊條件)。城鎮中心聯姻按鈕的可按性判斷
## (base_action_panel.gd)跟聯姻流程面板(StrongholdMarriagePanel)的人選清單共用同一份,
## 避免兩邊篩選條件各自維護、日後改一邊忘了改另一邊。
static func eligible_proposers(characters: Array[Character]) -> Array[Character]:
	var result: Array[Character] = []
	for character in characters:
		if not character.is_disabled and character.mate == null:
			result.append(character)
	return result


## 告白成功率:玩家選的角色正是對方屬意的 intended_target 時 100% 接受,選了其他人
## (等於是拿別人去反告白,不是對方原本想要的人)只有 20%——見
## System/event/town/town_tavern_event.gd 的告白後續分支,沒骰中就是真的告白失敗,
## 沒有補骰的餘地。
static func acceptance_chance(picked_character: Character, intended_target: Character) -> float:
	return 100.0 if picked_character == intended_target else 20.0


## 依 acceptance_chance() 骰一次,回傳這次告白是否成功。
static func roll_acceptance(picked_character: Character, intended_target: Character) -> bool:
	return Util.get_random_float(0.0, 100.0) < acceptance_chance(picked_character, intended_target)


## 城鎮中心聯姻流程(見 Scenes/Base/base_action_panel.gd 的 STRONGHOLD 分支)專用的固定
## 成功率——跟酒館告白的 acceptance_chance() 不是同一套機制:這裡沒有「對方屬意的
## intended_target」概念(候選人是玩家主動去信求來的人選,沒有任何一個是「本來就屬意
## 玩家」的對象),不論選中哪一位都固定 50%,不骰第二次。
const ALLIANCE_SUCCESS_CHANCE_PERCENT := 50.0

static func roll_alliance_success() -> bool:
	return Util.get_random_float(0.0, 100.0) < ALLIANCE_SUCCESS_CHANCE_PERCENT
