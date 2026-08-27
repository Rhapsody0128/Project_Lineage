class_name BattleReward
extends RefCounted

## RankType(F..SSS)分別對應的戰鬥勝利 EXP,先用等差遞增的預留位置數值,之後依遊戲數值
## 調整這張表即可,不用動呼叫端。
const RANK_EXP: Array[int] = [50, 100, 150, 200, 250, 300, 350, 400, 450]

static func exp_for_rank(rank_type: int) -> int:
	return RANK_EXP[clampi(rank_type, 0, RANK_EXP.size() - 1)]

## 戰鬥勝利(SELF_WIN)後,依敵方 Party 的 rank_type 查表,把「完整」EXP(不是平分)發給
## 我方在場的每一個角色。戰敗/平手不呼叫這裡。
static func grant_victory_exp(battle: Battle) -> void:
	if battle.result != GameEnums.BattleResultType.SELF_WIN:
		return
	var exp_amount := exp_for_rank(battle.enemy_rank_type)
	for battle_character in battle.self_characteres:
		battle_character.character.gain_exp(exp_amount)

## 根據地生產建築每月派駐結算用,只給戰鬥全額經驗的 10%——派駐是零風險、零操作的被動
## 養成,不能跟主動打仗的獎勵同量級。沿用 RANK_EXP 表,不重新設計曲線。
static func exp_for_dispatch(rank_type: int) -> int:
	return int(exp_for_rank(rank_type) * 0.1)

## RankType(F..SSS)分別對應的戰鬥勝利金錢獎勵/戰敗金錢損失。金錢庫存已無上限(見
## System/base/base_warehouse.gd,BaseResourceStore.add() 對 GOLD 特殊處理不再封頂),
## 曲線比 RANK_EXP 陡許多——遊蕩者難度(等級/人數,見 PartyController.RANK_LEVEL_RANGE/
## RANK_PARTY_SIZE_RANGE)越高才值得打,低階遊蕩者金錢報酬刻意壓低,不讓玩家有動機一直
## 刷最簡單的對手。懲罰抓在同級獎勵的六到七成,輸了會痛但不至於直接傾家蕩產。先用預留
## 位置數值,之後依遊戲數值調整這兩張表即可,不用動呼叫端。
const RANK_MONEY_REWARD: Array[int] = [30, 70, 120, 200, 300, 450, 650, 900, 1200]
const RANK_MONEY_PENALTY: Array[int] = [20, 45, 80, 130, 200, 300, 430, 600, 800]

static func money_reward_for_rank(rank_type: int) -> int:
	return RANK_MONEY_REWARD[clampi(rank_type, 0, RANK_MONEY_REWARD.size() - 1)]

static func money_penalty_for_rank(rank_type: int) -> int:
	return RANK_MONEY_PENALTY[clampi(rank_type, 0, RANK_MONEY_PENALTY.size() - 1)]

## 戰鬥勝利依敵方 rank_type 發放金錢獎勵;戰敗依同一張難度表(獎勵的六到七成)扣錢,
## 最多扣到現有存量歸零、不會扣成負數;平手不獎不罰。
static func settle_money(battle: Battle) -> void:
	if battle.result == GameEnums.BattleResultType.SELF_WIN:
		BaseResourceStore.add(GameEnums.ResourceType.GOLD, money_reward_for_rank(battle.enemy_rank_type))
	elif battle.result == GameEnums.BattleResultType.ENEMY_WIN:
		var penalty := mini(money_penalty_for_rank(battle.enemy_rank_type), BaseResourceStore.get_display_amount(GameEnums.ResourceType.GOLD))
		BaseResourceStore.spend({GameEnums.ResourceType.GOLD: penalty})

## RankType(F..SSS)分別對應的戰鬥勝利國家好感度獎勵(見 System/event/map/
## roaming_enemy_event.gd:遊蕩者統一是離生成點最近城鎮的 nation,見
## RoamingEnemySpawner._nearest_town_nation())。只有贏,沒有輸的懲罰——玩家在自己國家
## 附近被盜賊打贏地方盜賊算是在替該國除害,打輸單純沒收穫,不倒扣好感度。累積好感度對應
## 到 RankType 等級的門檻表見 System/nation/nation_favor_rank.gd。
const RANK_NATION_FAVOR: Array[int] = [1, 2, 3, 5, 8, 12, 18, 27, 40]

static func favor_for_rank(rank_type: int) -> int:
	return RANK_NATION_FAVOR[clampi(rank_type, 0, RANK_NATION_FAVOR.size() - 1)]

## 戰鬥勝利(SELF_WIN)後,敵方 Party 有單一所屬國家(enemy_nation_type != -1)才加好感度;
## 戰敗/平手,或敵方 Party 沒有單一所屬國家,都不呼叫這裡的邏輯。
static func grant_victory_favor(battle: Battle) -> void:
	if battle.result != GameEnums.BattleResultType.SELF_WIN:
		return
	if battle.enemy_nation_type == -1:
		return
	NationFavorStore.add_favor(battle.enemy_nation_type, favor_for_rank(battle.enemy_rank_type))

## 戰鬥結束(勝/敗/平手)一律呼叫,跟 grant_victory_exp/settle_money 是同一組(見呼叫點)。
## 不看敵方 RankType 強弱,固定幅度直接轉發給 MoraleStore(見該檔案「五、戰鬥對士氣的
## 影響」設計),數值集中在 MoraleStore 的常數,這裡不重複維護一份。
static func settle_morale(battle: Battle) -> void:
	MoraleStore.record_battle_result(battle.result)
