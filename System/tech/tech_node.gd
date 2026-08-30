class_name TechNode
extends RefCounted

## 科技樹單一節點的靜態資料(見 System/tech/tech_library.gd)。設計比照技能系統
## 「資料欄位驅動,不寫同名效果函式」的原則——effect_type + effect_value 是唯一的效果
## 表達方式,TechStore.get_bonus()/get_multiplier() 統一加總/連乘,呼叫端(BaseProduction、
## CombatResolver……)各自決定怎麼套用。
##
## 每條「機制鏈」(thread)是一串同一個 effect_type 在不同 rank 疊層的節點,鏈內第一層
## prerequisite_id 是空字串,之後每層的前置是鏈內前一層的 id。同一條鏈內 rank 必須嚴格
## 遞增(不重複),否則會有兩個節點同時卡在同一個科學研究所等級門檻上,浪費一個 rank 檔位
## ——TechLibrary.build_thread() 已經用 assert 擋這件事。

var id: String
var branch: GameEnums.TechBranch
var thread: String
var rank: GameEnums.RankType
var tier: int  ## 鏈內第幾層(1-based),純顯示用,不影響解鎖判定。
var tier_count: int  ## 這條鏈總共幾層,純顯示用。
var display_name: String
## 卡片上顯示的簡短描述,刻意不寫確切數值(見 CLAUDE.md 需求:玩家看卡片只需要方向感,
## 確切數值留給 effect_detail 或之後的懸停/詳情面板)。
var card_description: String
## 完整中文效果說明,含確切數值/機率,給程式維護者跟之後可能的詳情 UI 用。
var effect_detail: String
var effect_type: GameEnums.TechEffectType
var effect_value: float
## 鏈內前一層的 id;鏈首是空字串,代表只看科學研究所等級,不需要前置科技。
var prerequisite_id: String
var cost: int
## 掛勾點備註/實作難度,純開發用,不會顯示給玩家看。
var dev_note: String
var feasibility: String  ## "low" | "mid"


func _init(
	p_id: String,
	p_branch: GameEnums.TechBranch,
	p_thread: String,
	p_rank: GameEnums.RankType,
	p_tier: int,
	p_tier_count: int,
	p_display_name: String,
	p_card_description: String,
	p_effect_detail: String,
	p_effect_type: GameEnums.TechEffectType,
	p_effect_value: float,
	p_prerequisite_id: String,
	p_cost: int,
	p_dev_note: String,
	p_feasibility: String
) -> void:
	id = p_id
	branch = p_branch
	thread = p_thread
	rank = p_rank
	tier = p_tier
	tier_count = p_tier_count
	display_name = p_display_name
	card_description = p_card_description
	effect_detail = p_effect_detail
	effect_type = p_effect_type
	effect_value = p_effect_value
	prerequisite_id = p_prerequisite_id
	cost = p_cost
	dev_note = p_dev_note
	feasibility = p_feasibility


## 解鎖需要的科學研究所等級:F=Lv1、E=Lv2……SSS=Lv9,直接沿用建築現有 1~9 級,不另外設計換算表。
func required_institute_level() -> int:
	return rank + 1


func has_prerequisite() -> bool:
	return not prerequisite_id.is_empty()
