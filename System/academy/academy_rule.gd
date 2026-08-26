class_name AcademyRule
extends RefCounted

## 出生當下由玩家決定送去哪個國家的學院留學(見 Scenes/LifeEvent/life_event_scene.gd),
## 立即生效:換上該國對應武器、並用跟 CharacterController.get_random_character() 相同的
## 初始技能抽選邏輯(SkillController.get_random_initial_skill_list())重骰一次技能表——
## 小孩出生時本來不帶技能(見該函式檔頭註解「之後靠這支函式給...方便未來『小孩慢慢學會
## 技能』的流程也呼叫同一套抽選規則」),這裡正是那個預留的使用時機。六國↔六武器對照
## 沿用《遊戲企劃設定總整理.md》59-66 行既有企劃表(獅→大劍/鷹→弓/豹→匕首/熊→大盾/
## 龍→法仗/鹿→捕夢網),跟 GameEnums.WeaponType/BloodlineNation 兩個 enum 各自宣告順序
## 不同(豹/熊對調),不能用 enum 值直接轉換,必須查表。

const NATION_WEAPON := {
	GameEnums.BloodlineNation.LION: GameEnums.WeaponType.SWORD,
	GameEnums.BloodlineNation.EAGLE: GameEnums.WeaponType.BOW,
	GameEnums.BloodlineNation.LEOPARD: GameEnums.WeaponType.DAGGER,
	GameEnums.BloodlineNation.BEAR: GameEnums.WeaponType.SHIELD,
	GameEnums.BloodlineNation.DRAGON: GameEnums.WeaponType.STAFF,
	GameEnums.BloodlineNation.DEER: GameEnums.WeaponType.DREAMCATCHER,
}

## 留學選項按鈕上的一句風味文案(玩家視角的敘述,不是機制說明),對應
## 《遊戲企劃設定總整理.md》59-66 行各國「主要方向」欄位的氣質。
const NATION_FLAVOR := {
	GameEnums.BloodlineNation.LION: "王者之劍，所向披靡",
	GameEnums.BloodlineNation.EAGLE: "獵者之眼，百步穿楊",
	GameEnums.BloodlineNation.LEOPARD: "暗影疾行，一擊必殺",
	GameEnums.BloodlineNation.BEAR: "巍然如山，寸步不讓",
	GameEnums.BloodlineNation.DRAGON: "祕法如淵，翻雲覆雨",
	GameEnums.BloodlineNation.DEER: "聖潔庇佑，撫平傷痛",
}


static func weapon_for_nation(nation: int) -> int:
	return NATION_WEAPON[nation]


## 反查:武器→國家(新生兒命名畫面預設勾選出生當下已遺傳到的武器對應國家用,見
## Scenes/LifeEvent/life_event_scene.gd)。NATION_WEAPON 各國武器互不重複,查無對應時
## 回傳 -1(呼叫端據此判斷不預選)。
static func nation_for_weapon(weapon: int) -> int:
	for nation in NATION_WEAPON:
		if NATION_WEAPON[nation] == weapon:
			return nation
	return -1


static func flavor_for_nation(nation: int) -> String:
	return NATION_FLAVOR[nation]


static func enroll(character: Character, nation: int) -> void:
	character.weapon = weapon_for_nation(nation)
	var noble_rank := Character.compute_noble_bloodline_rank(character.bloodline)
	character.skill_list = SkillController.get_random_initial_skill_list(character.weapon, noble_rank, character.bloodline)
