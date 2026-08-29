extends Node

# =========================================================
# 根據地「哪棟建築派了哪些角色」的派遣紀錄(autoload,見 project.godot)。跟
# BaseResourceStore 同一套慣例:session 狀態放這裡,不放 System/。一棟建築最多派
# BaseBuildingProgressStore.get_max_workers() 位角色(容量=建築等級)、一位角色同一時間
# 只能派 1 棟建築,靠 dispatch() 內先呼叫 undispatch_character() 清掉舊指派來保證。
#
# 用 GameEnums.BuildingType(Building.type)當 key,不是字串——18 種建築類型本來就
# 一一對應,不需要另外維護一份 id,見 System/base/building/building.gd 開頭註解。
#
# 每月結算不是自己註冊 WorldTimeController,改由 MonthlySettlementStore 統一協調
# (見該檔案開頭註解)——商隊站/黑市自動兌換、CHARACTER_ROSTER 維持費都會在同一個月份
# 邊界搶同一份 BaseResourceStore 庫存,獨立各自註冊會有「先執行的把資源用掉/生出來,
# 後執行的用到不該看到的當月庫存變動」的競態,所以外部呼叫端一律透過 settle(apply,
# available) 拿到的共用快照字典來讀寫,不直接呼叫 BaseResourceStore.get_amount()。
#
# changed 訊號給 Scripts/UI/header_bar.gd 的「詳細」面板用:派遣異動當下就會改變下月
# 派駐生產的預估增減量,面板開著時要能即時反映,不能只在 BaseResourceStore 實際存量
# 變動(那要等到月結算才會發生)時才刷新,否則玩家剛派工/召回,面板顯示的還是派遣
# 異動前的舊預估。
# =========================================================

signal changed

var _assignments: Dictionary = {}


## 建築未解鎖(0 級)、名額已滿都回傳 false 且不指派,呼叫端(Scenes/Base/base_action_panel.gd)
## 用回傳值決定要不要顯示提示。角色已編入小隊時只有小隊隊長會被擋——小隊至少要留一位隊長
## (跟 character_roster.gd._is_protected_from_dismissal() 擋隊長解雇同一個理由);非隊長
## 成員派去工作會直接被移出小隊(grid/characteres/battle_cost_positions 一併清掉,比照
## CharacterDeathController.kill() 的既有寫法),跟 PartyEditGrid.place() 允許把已派駐角色
## 重新拖回小隊(見該檔案)是同一組雙向轉換,不再是完全互斥。
##
## 歷練中/待確認歸隊的角色一律擋下,不允許同時派去建築工作——跟「歷練」那邊反過來一樣
## (BarracksExpeditionStore.send() 已經擋派駐中的角色去歷練),兩邊要互相擋才不會出現
## 一個人同時「歷練中」又「在工廠上班」的矛盾狀態(見 CLAUDE.md 這次需求)。
func dispatch(building_type: GameEnums.BuildingType, character_id: String) -> bool:
	if BarracksExpeditionStore.is_on_expedition(character_id) or BarracksExpeditionStore.is_awaiting_collection(character_id):
		return false
	if PartyStore.party != null:
		for character in PartyStore.party.characteres:
			if character.id != character_id:
				continue
			if PartyStore.party.leader == character:
				return false
			if PartyStore.grid != null:
				PartyStore.grid.remove(character)
			PartyStore.party.characteres.erase(character)
			PartyStore.party.battle_cost_positions.erase(character)
			break
	undispatch_character(character_id)
	var current: Array = _assignments.get(building_type, [])
	if current.size() >= BaseBuildingProgressStore.get_max_workers(building_type):
		return false
	current.append(character_id)
	_assignments[building_type] = current
	changed.emit()
	return true


## 一棟建築現在可能同時有多人派駐,召回要指定是哪一位。
func undispatch(building_type: GameEnums.BuildingType, character_id: String) -> void:
	var current: Array = _assignments.get(building_type, [])
	current.erase(character_id)
	_assignments[building_type] = current
	changed.emit()


func undispatch_character(character_id: String) -> void:
	for building_type in _assignments.keys():
		var current: Array = _assignments[building_type]
		if not current.has(character_id):
			continue
		current.erase(character_id)
		changed.emit()


func get_dispatched_character_ids(building_type: GameEnums.BuildingType) -> Array[String]:
	var ids: Array[String] = []
	ids.assign(_assignments.get(building_type, []))
	return ids


## 給 Scenes/Base/base_action_panel.gd 顯示派遣中角色清單用,查不到的 id(角色已從
## AllCharacterStore 移除)直接跳過不塞 null。
func get_dispatched_characters(building_type: GameEnums.BuildingType) -> Array[Character]:
	var characters: Array[Character] = []
	for character_id in get_dispatched_character_ids(building_type):
		var character := find_character(character_id)
		if character != null:
			characters.append(character)
	return characters


func is_character_dispatched(character_id: String) -> bool:
	for building_type in _assignments:
		if (_assignments[building_type] as Array).has(character_id):
			return true
	return false


## 查角色目前派駐哪一棟建築,查不到回傳 -1(見 CharacterStatusRule.get_status_label()
## 要組「在OOO工作」的顯示文字)。
func get_dispatched_building_type(character_id: String) -> int:
	for building_type in _assignments:
		if (_assignments[building_type] as Array).has(character_id):
			return building_type
	return -1


func to_save_data() -> Dictionary:
	return SaveDataCodec.int_keyed_to_str(_assignments)


func load_save_data(data: Dictionary) -> void:
	_assignments = SaveDataCodec.str_keyed_to_int(data)


func find_character(character_id: String) -> Character:
	for character in AllCharacterStore.all_characteres:
		if character.id == character_id:
			return character
	return null


func _recipe_for(building: Building) -> WorkshopRecipe:
	return (
		WorkshopRecipeStore.get_selected() if building.type == GameEnums.BuildingType.WORKSHOP
		else building.fixed_recipe
	)


## 依建築目前生效的配方把理論產出換算成實際產出,交給 WorkshopProduction.resolve() 統一
## 換算——原料不足時不再整個月掛零,改成按原料比例部分生產,沒做完的零頭留在
## BaseResourceStore 裡累積到下個月(見該檔案開頭註解)。fixed_recipe 是 null 的建築直接
## 原樣回傳理論產出、不消耗。
##
## `available` 是呼叫端(MonthlySettlementStore._run())在四支 store 的 settle() 都還沒
## 呼叫之前,對全部 GameEnums.ResourceType 一次補滿的「本月尚未動用的庫存」共用快照,之後
## 被本函式扣減——刻意不去讀 BaseResourceStore 的即時餘額,因為本月結算不是只有這裡在動:
## 某棟建築(甚至商隊站兌換/CHARACTER_ROSTER 維持費)當月剛產出/剛扣掉的資源,不能拿來餵給
## 同一輪另一個消耗方當月的判定(那筆產出要等到下個月才算「庫存」)。下面
## `if not available.has(...)` 只是給「直接單獨呼叫這支 store 的 settle()」時的防呆
## (正常路徑一律已經補好值,不會落到這支);千萬不能改成無條件覆寫或拿掉判斷式改讀
## BaseResourceStore.get_amount(),否則 apply == true 時,迴圈跑到前段的建築(例如狩獵場
## 產毛皮)已經真的呼叫 BaseResourceStore.add() 寫回庫存,後段建築(例如抄書院消耗毛皮)
## 才第一次讀到的就會是「這個月剛產出」的污染值,跟 apply == false 的預覽兜不起來(見
## MonthlySettlementStore 檔頭註解)。多方搶同一種資源時,仍照呼叫順序先到先扣。
func _resolve_recipe(building: Building, theoretical_output: int, available: Dictionary) -> Dictionary:
	var recipe := _recipe_for(building)
	if recipe == null:
		return {"output": theoretical_output, "consumed": {}}
	for resource_type in recipe.inputs:
		if not available.has(resource_type):
			available[resource_type] = BaseResourceStore.get_amount(resource_type)
	var result := WorkshopProduction.resolve(recipe, theoretical_output, available)
	for resource_type in result.consumed:
		available[resource_type] -= result.consumed[resource_type]
	return result


## 共用結算迴圈:`apply == true` 時真的扣款/加值/發經驗,否則只回傳淨變動量供預覽、不動
## BaseResourceStore。`available` 由呼叫端(MonthlySettlementStore)傳入並貫穿整場月結算
## 共用,不在這裡自建——才不會出現「這棟建築看不到別的 autoload 當月已經動用掉的庫存」
## 的競態,詳見 _resolve_recipe() 開頭註解跟 MonthlySettlementStore 檔頭。
## `remaining_capacity` 同一份精神:產物倉庫已經沒有剩餘空間就整棟跳過,不生產也不消耗
## 原料——不然做出來的量會被 BaseResourceStore.add() 直接捨棄(見該檔案倉庫上限說明),
## 原料卻已經真的扣掉,等於拿珍貴的初階資材換了一堆進不了倉庫、平白蒸發的成品。判斷一律
## 讀 remaining_capacity 這份月初快照而非即時呼叫 BaseResourceStore.remaining_capacity(),
## 原因跟 available 一樣(見 MonthlySettlementStore 檔頭註解)——固定不變,不會因為同一輪
## 內別的建築先把倉庫填滿/騰空而跟著翻盤。這裡刻意維持「整棟跳過、不生產」的簡化(不像
## BaseExchangeStore 買入快頂到倉庫上限時會等比例砍量——生產沒有直接金錢成本,砍量的
## 急迫性比兌換低,見 BaseExchangeStore 開頭註解),但仍會把這棟實際產出的量從
## remaining_capacity 扣掉,讓排在後面的 BaseExchangeStore 看到正確的剩餘空間,不會誤以為
## 倉庫還是滿的空的而超買。
func settle(apply: bool, available: Dictionary, remaining_capacity: Dictionary) -> Dictionary:
	var delta: Dictionary = {}
	for building in BuildingLibrary.get_all():
		if not building.is_production_building():
			continue
		if not BaseBuildingProgressStore.is_unlocked(building.type):
			continue
		if not BaseBuildingProgressStore.is_active(building.type):
			continue
		if not remaining_capacity.has(building.produces):
			remaining_capacity[building.produces] = BaseResourceStore.remaining_capacity(building.produces)
		if remaining_capacity[building.produces] <= 0:
			continue
		var characters: Array[Character] = get_dispatched_characters(building.type).filter(
			func(character: Character) -> bool: return not character.is_disabled
		)
		if characters.is_empty():
			continue
		var level := BaseBuildingProgressStore.get_level(building.type)
		var theoretical_output := BaseProduction.compute_monthly_yield(building, characters, level)
		var result := _resolve_recipe(building, theoretical_output, available)
		delta[building.produces] = delta.get(building.produces, 0) + result.output
		if remaining_capacity[building.produces] >= 0:
			remaining_capacity[building.produces] -= result.output
		for resource_type in result.consumed:
			delta[resource_type] = delta.get(resource_type, 0) - result.consumed[resource_type]
		if apply:
			BaseResourceStore.spend(result.consumed)
			BaseResourceStore.add(building.produces, result.output)
			var rank := BaseBuildingProgressStore.get_rank(building.type)
			var exp_amount := BattleReward.exp_for_dispatch(rank)
			for character in characters:
				character.gain_exp(exp_amount)
	return delta
