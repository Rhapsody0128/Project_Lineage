class_name Party
extends RefCounted

# =========================================================
# 小隊:由多個 Character 組成的編隊單位。純粹是組織/編制上的分組,
# 不參與戰鬥判定——戰場上每個 Character 都是各自獨立的作戰單位
# (見 System/battle/battle_character.gd),Party 只負責「這個小隊裡有哪些角色」。
# =========================================================

var name: String
var characteres: Array[Character]
## 隊長:目前只用來在戰場上標示(金色遮罩)與判斷隊長陣亡即結束戰鬥,
## 不影響小隊本身的組織邏輯。未指定時預設隊伍第一位角色。
var leader: Character

## PartyEdit 編成時記錄的站位(Character -> PartyEditGrid 座標,即該角色 battle_cost
## 佔位格/軸心落在網格上的位置)。Battle 開戰佈陣時(見 battle.gd 的
## _deploy_side())如果查得到某個角色的站位,直接照這個位置站,不套用預設的
## 靠邊縱隊排法。PartyController.get_random_party() 生的隨機小隊不會記錄任何
## 站位,一律吃預設佈陣,兩種小隊可以混合出現(例如玩家小隊 vs 隨機敵方小隊)、
## 互不影響。
var battle_cost_positions: Dictionary = {}  # Character -> Vector2i

## 這個小隊的整體評級,PartyController.get_random_party() 建立時一定會賦值(呼叫端有
## 指定就用指定值,沒指定就額外隨機骰一個)——純粹用來決定戰鬥勝利 EXP(見
## System/battle/battle_reward.gd),不影響隊內角色 Bloodline/Potential 各自的隨機生成。
## 非 PartyController 生成的 Party(例如玩家自編小隊)預設 -1,不參與 EXP 判定
## (EXP 只看被擊敗的敵方 Party)。
var rank_type: int = -1

## 這個小隊統一所屬的 GameEnums.BloodlineNation,只有 PartyController.get_random_party()
## 呼叫端明確指定 nation 參數時才會有值(見該函式),用來決定戰鬥勝利後
## System/battle/battle_reward.gd 的好感度要加給哪個國家。沒指定 nation 時(-1,各角色
## 各自獨立隨機血統國家)維持預設 -1,代表這支小隊沒有單一所屬國家,不參與好感度判定。
var nation_type: int = -1

## 這個小隊在戰鬥中可施放的奧義(見 System/ultimate/),即時戰鬥模式
## (Battle.start_realtime())才會用到,由 PartyController 建立小隊時指派預設值
## (UltimateLibrary.default_ultimates())。
var ultimates: Array[Ultimate] = []

func _init(p_name: String, p_characteres: Array[Character], p_leader: Character = null) -> void:
	name = p_name
	characteres = p_characteres
	leader = p_leader if p_leader != null else (characteres[0] if not characteres.is_empty() else null)

func set_battle_position(character: Character, cell: Vector2i) -> void:
	battle_cost_positions[character] = cell

func has_battle_position(character: Character) -> bool:
	return battle_cost_positions.has(character)

func get_battle_position(character: Character) -> Vector2i:
	return battle_cost_positions.get(character, Vector2i.ZERO)
