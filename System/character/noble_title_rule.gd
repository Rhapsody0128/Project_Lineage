class_name NobleTitleRule
extends RefCounted

## 身分/爵位規則:GameEnums.RankType 對照「平民(F)~王族(SSS)」九階稱號,見
## TITLE_LABELS。跟 Character.noble_bloodline_rank(血統評分)是兩個獨立欄位,刻意不
## 綁定——允許角色血統區間跟身分不同(高血民間平民、低血受封貴族都合理存在)。只有
## CharacterController 隨機產生的角色會依血統分布大致套用這裡的對照表(見
## rank_for_bloodline()),出生小孩改走世襲規則(見 rank_for_inheritance()),兩者互不
## 影響,身分欄位本身之後(聯姻/繼承/晉升等)可以自由改動。

const TITLE_LABELS: Array[String] = ["平民", "士紳", "騎士", "男爵", "子爵", "伯爵", "侯爵", "公爵", "王族"]

static func label_for_rank(rank: int) -> String:
	return TITLE_LABELS[rank]

## 姓氏門檻:只在「隨機產生新角色」當下決定要不要抽一個姓氏——平民/士紳不冠姓氏,騎士
## (D)以上才會抽(見 CharacterController.get_random_character())。純粹是生成規則,不是
## 顯示規則:一旦 Character.last_name 定案(非空字串),不管角色之後身分升降都會照樣一路
## 顯示下去(見 Character.title_full_name 的呼叫端註解)——小孩繼承父親姓氏(見
## InheritanceController.create_child())、玩家固定主角(一開始就帶姓氏)都不會再經過這裡
## 這道門檻。
const LAST_NAME_MIN_RANK := GameEnums.RankType.D

static func has_last_name(rank: int) -> bool:
	return rank >= LAST_NAME_MIN_RANK

## 隨機生成角色的初始身分:依血統總高階百分比(Bloodline.get_total_noble_percentage(),
## 0~100)每 STEP(12.5)一階對照 GameEnums.RankType——[0,12.5]=平民,(12.5,25]=士紳,
## ……(87.5,100)=公爵,100=王族。跟 Character.compute_noble_bloodline_rank() 的分段
## 邊界刻意不同(那個函式是 [0,12.5)=F 起跳的血統評分,這裡是身分稱號,各自獨立)。
static func rank_for_bloodline(total_noble_percentage: float) -> int:
	if total_noble_percentage >= Bloodline.TOTAL:
		return GameEnums.RankType.SSS
	var rank := 0
	for i in range(7):
		if total_noble_percentage > Bloodline.STEP * (i + 1):
			rank = i + 1
	return rank

## 嫡系子女名額:同一對父母的第 1、2 胎(見 Character.give_birth() 算出的 birth_order)
## 繼承父母兩人身分中較高者;第 3 胎起,若父母身分較高者已達男爵(NON_HEIR_TITLE_RANK)
## 以上,降階預設為騎士,不繼承父母身分——但父母身分較高者本來就在騎士以下(平民/士紳/
## 騎士)時,「降階變騎士」等於平白升階,不套用這條規則,一律照樣繼承父母身分中較高者
## (不管第幾胎)。換句話說,只有貴族(男爵以上)家庭才有「非嫡系子女降階封騎士」這件事。
const HEIR_QUOTA := 2
const NON_HEIR_TITLE_RANK := GameEnums.RankType.D # 騎士

static func rank_for_inheritance(parent_a_rank: int, parent_b_rank: int, birth_order: int) -> int:
	var inherited_rank := maxi(parent_a_rank, parent_b_rank)
	if birth_order <= HEIR_QUOTA:
		return inherited_rank
	if inherited_rank > NON_HEIR_TITLE_RANK:
		return NON_HEIR_TITLE_RANK
	return inherited_rank

## 每名角色每月薪水,依身分爵位越高越貴,順序對應 GameEnums.RankType,最貴的王族一人 2
## (見 MoraleStore.settle() 加總全體 CharacterRosterStore 角色的薪水,取代舊版齊頭式
## WAGE_PER_CHARACTER 常數)。
const WAGE_BY_TITLE_RANK: Array[float] = [0.2, 0.3, 0.45, 0.65, 0.9, 1.2, 1.5, 1.75, 2.0]

static func wage_for_rank(rank: int) -> float:
	return WAGE_BY_TITLE_RANK[rank]
