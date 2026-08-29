class_name CharacterStatusRule
extends RefCounted

# =========================================================
# 角色目前狀態(GameEnums.CharacterStatus)的唯一判定/顯示入口——死亡/解雇讀 Character
# 本身的旗標,派遣中要查 BaseDispatchStore(autoload,同 AgingRule 呼叫
# BaseBuildingProgressStore 的既有慣例,不是 Character 自己該知道的事)。判定順序即
# 優先序:死亡 > 解雇 > 編隊中 > 派遣中 > 歷練中,其餘一律服役中——同一時間只會落在
# 其中一種狀態(編隊中/派遣中/歷練中本來就互斥,見 BaseDispatchStore.dispatch()/
# BarracksExpeditionStore.send())。
# =========================================================

static func get_status_type(character: Character) -> GameEnums.CharacterStatus:
	if character.is_dead:
		return GameEnums.CharacterStatus.DEAD
	if character.is_dismissed:
		return GameEnums.CharacterStatus.DISMISSED
	if PartyStore.party != null and PartyStore.party.characteres.has(character):
		return GameEnums.CharacterStatus.IN_PARTY
	if BaseDispatchStore.is_character_dispatched(character.id):
		return GameEnums.CharacterStatus.WORKING
	if BarracksExpeditionStore.is_on_expedition(character.id):
		return GameEnums.CharacterStatus.ON_EXPEDITION
	return GameEnums.CharacterStatus.ACTIVE


## WORKING 要內插目前派遣的建築名稱,不能只靠靜態 label 陣列,所以獨立成一個函式讓畫面端
## 統一呼叫這裡取得完整顯示文字,不要自己 match get_status_type() 再組字串。
static func get_status_label(character: Character) -> String:
	match get_status_type(character):
		GameEnums.CharacterStatus.DEAD:
			return "已故"
		GameEnums.CharacterStatus.DISMISSED:
			return "已離隊"
		GameEnums.CharacterStatus.IN_PARTY:
			return "編隊中"
		GameEnums.CharacterStatus.WORKING:
			var building_type := BaseDispatchStore.get_dispatched_building_type(character.id)
			return "在%s工作" % GameEnums.building_type_label(building_type)
		GameEnums.CharacterStatus.ON_EXPEDITION:
			return "歷練中"
		_:
			return "服役中"
