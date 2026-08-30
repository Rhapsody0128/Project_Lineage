class_name MarriageRule
extends RefCounted

## 判斷 self_character 能不能向 target_character 告白:性別要相反(目前只有
## MALE/FEMALE 兩種),雙方都要未婚(mate == null,呼應企劃「一生只能結一次婚」規則),
## 也都不能已經排進婚禮倒數(WeddingQueueStore.is_pending(),見該檔案)——已經有一樁
## 婚約在等 30 天後完婚的角色,不能同時再被告白/反告白/聯姻談成第二樁,避免同一個角色
## 在倒數期間又結一次婚搞混。
static func can_propose(self_character: Character, target_character: Character) -> bool:
	return (
		self_character.mate == null
		and target_character.mate == null
		and self_character.gender != target_character.gender
		and not WeddingQueueStore.is_pending(self_character.id)
		and not WeddingQueueStore.is_pending(target_character.id)
	)


## 聯姻候選發起人清單:未婚(mate == null)、未禁用、且沒有已經排進婚禮倒數
## (WeddingQueueStore.is_pending())的角色——呼應 can_propose() 的前提(性別互斥要等挑到
## 對象後才判定,這裡先篩單邊條件)。城鎮中心聯姻按鈕的可按性判斷(base_action_panel.gd)
## 跟聯姻流程面板(StrongholdMarriagePanel)的人選清單共用同一份,避免兩邊篩選條件各自
## 維護、日後改一邊忘了改另一邊。
static func eligible_proposers(characters: Array[Character]) -> Array[Character]:
	var result: Array[Character] = []
	for character in characters:
		if not character.is_disabled and character.mate == null and not WeddingQueueStore.is_pending(character.id):
			result.append(character)
	return result


## 告白成功率:玩家選的角色正是對方屬意的 intended_target 時 100% 接受,選了其他人
## (等於是拿別人去反告白,不是對方原本想要的人)只有 20%——見
## System/event/town/town_tavern_event.gd 的告白後續分支,沒骰中就是真的告白失敗,
## 沒有補骰的餘地。
## 「婚姻禮制」科技線(TechEffectType.MARRIAGE_SUCCESS_CHANCE_ADD)加在反告白基準值上,
## 跟 ALLIANCE_SUCCESS_CHANCE_PERCENT 共用同一個加成來源,clamp 在 100% 封頂。選中
## intended_target 本來就 100% 接受,加成對這個分支沒有意義,不需要另外套用。
static func acceptance_chance(picked_character: Character, intended_target: Character) -> float:
	if picked_character == intended_target:
		return 100.0
	return minf(20.0 + TechStore.get_bonus(GameEnums.TechEffectType.MARRIAGE_SUCCESS_CHANCE_ADD), 100.0)


## 依 acceptance_chance() 骰一次,回傳這次告白是否成功。
static func roll_acceptance(picked_character: Character, intended_target: Character) -> bool:
	return Util.get_random_float(0.0, 100.0) < acceptance_chance(picked_character, intended_target)


## 城鎮中心聯姻流程(見 Scenes/Base/base_action_panel.gd 的 STRONGHOLD 分支)專用的固定
## 成功率——跟酒館告白的 acceptance_chance() 不是同一套機制:這裡沒有「對方屬意的
## intended_target」概念(候選人是玩家主動去信求來的人選,沒有任何一個是「本來就屬意
## 玩家」的對象),不論選中哪一位都固定 50%,不骰第二次。
const ALLIANCE_SUCCESS_CHANCE_PERCENT := 50.0

## 「婚姻禮制」科技線同一個加成來源(見 acceptance_chance() 註解),clamp 在 100% 封頂。
static func alliance_success_chance() -> float:
	return minf(ALLIANCE_SUCCESS_CHANCE_PERCENT + TechStore.get_bonus(GameEnums.TechEffectType.MARRIAGE_SUCCESS_CHANCE_ADD), 100.0)


static func roll_alliance_success() -> bool:
	return Util.get_random_float(0.0, 100.0) < alliance_success_chance()


## 寄信國家門檻:對某國好感度要達到 C 以上才能寄信求親——好感度只決定「能不能寄信」,
## 不影響回信候選人評級(候選人評級改依 proposer 自身爵位決定,見
## MarriageCandidateGenerator 檔頭註解)。
const MIN_FAVOR_RANK_TO_SEND_LETTER := GameEnums.RankType.C

static func can_send_letter(nation: int) -> bool:
	return NationFavorRank.rank_for_favor(NationFavorStore.get_favor(nation)) >= MIN_FAVOR_RANK_TO_SEND_LETTER
