class_name Potential
extends RefCounted

## rank_from_ratio() 的換算基準,PotentialController 指定目標 RankType 生成 ratio 時
## 也要反推同一組數字,提升成 class 常數避免兩邊各自硬編一次。
const BASE_RATIO := 0.5
## 潛力 ratio 的真正上限——純評級跟血統加成後的最終值都封頂在這裡,是唯一定義
## (InheritanceConstants.POTENTIAL_RATIO_MAX 只是引用這裡,不要反過來在那邊另外
## 存一份數字)。RANK_GAP 的 9 級距直接切滿 [BASE_RATIO, MAX_RATIO) 整段,不留一段
## 「不含血統」的子區間給血統疊加——RANK 顯示的就是「這項素質最終(已含血統)的
## 強度落在哪裡」,血統加成因此會直接反映在 RANK 上;會不會超過 MAX_RATIO 交給
## BloodlineLibrary.apply_to_potential() 自己 clampf 兜底,不需要靠犧牲 RANK 的
## 解析度去預留安全邊界(上一版 RANK_ONLY_MAX_RATIO 就是多繞的這一圈,拿掉)。
const MAX_RATIO := 2.3
const RANK_GAP := (MAX_RATIO - BASE_RATIO) / (GameEnums.RankType.SSS + 1)

var strength: float
var vitality: float
var agility: float
var dexterity: float
var intelligence: float
var mentality: float
## 區間 0 - 200

var strength_ratio: float
var vitality_ratio: float
var agility_ratio: float
var dexterity_ratio: float
var intelligence_ratio: float
var mentality_ratio: float
## 區間 BASE_RATIO ~ MAX_RATIO,不要寫死數字,見上面常數區塊的說明。

var strength_rank: int
var vitality_rank: int
var agility_rank: int
var dexterity_rank: int
var intelligence_rank: int
var mentality_rank: int

func _init(
	p_strength: float,
	p_vitality: float,
	p_agility: float,
	p_dexterity: float,
	p_intelligence: float,
	p_mentality: float,
	p_strength_ratio: float,
	p_vitality_ratio: float,
	p_agility_ratio: float,
	p_dexterity_ratio: float,
	p_intelligence_ratio: float,
	p_mentality_ratio: float
) -> void:
	strength = p_strength
	vitality = p_vitality
	agility = p_agility
	dexterity = p_dexterity
	intelligence = p_intelligence
	mentality = p_mentality
	strength_ratio = p_strength_ratio
	vitality_ratio = p_vitality_ratio
	agility_ratio = p_agility_ratio
	dexterity_ratio = p_dexterity_ratio
	intelligence_ratio = p_intelligence_ratio
	mentality_ratio = p_mentality_ratio
	strength_rank = rank_from_ratio(strength_ratio)
	vitality_rank = rank_from_ratio(vitality_ratio)
	agility_rank = rank_from_ratio(agility_ratio)
	dexterity_rank = rank_from_ratio(dexterity_ratio)
	intelligence_rank = rank_from_ratio(intelligence_ratio)
	mentality_rank = rank_from_ratio(mentality_ratio)

## 根據比例計算評級
##
## 左閉右開(floori 的實際行為,不是四捨五入或右閉區間):第 n 級(F=0~SSS=8)的
## 區間是 [BASE_RATIO + n*RANK_GAP, BASE_RATIO + (n+1)*RANK_GAP)。刻意不在這裡列出
## 算好的數字表——RANK_GAP 是公式算出來的(見上面常數區塊),BASE_RATIO/MAX_RATIO
## 之後調整時這裡若寫死一份數字表會立刻過期、跟程式碼對不上(先前的版本就是這樣
## 壞掉:表格寫死的數字沒跟著常數變動同步更新,clamp 常數抄錯數字,SSS 永遠算不
## 出來)。要看目前實際切在哪,直接算 BASE_RATIO + n*RANK_GAP 或印出來看,不要猜。
## ratio 傳進來的時候已經是「純評級 + 血統加成」的最終值(見 CharacterController.
## get_random_character() 呼叫 BloodlineLibrary.apply_to_potential() 那一步),
## 這裡的級距因此也切滿最終值的完整範圍,血統加成疊多少、RANK 就跟著反映多少,
## 不會卡在某個子區間頂點就再也顯示不出差異。
static func rank_from_ratio(ratio: float) -> int:
	var rank := floori((ratio - BASE_RATIO) / RANK_GAP) + GameEnums.RankType.F

	return clampi(
		rank,
		GameEnums.RankType.F,
		GameEnums.RankType.SSS
	)
