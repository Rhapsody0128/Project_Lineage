class_name CharacterDeathController
extends RefCounted

## 角色死亡的唯一入口(見 CLAUDE.md「老年與死亡」):先清乾淨所有「需要角色實際在場」
## 的地方(小隊編成/根據地派遣),才把角色從 CharacterRosterStore(可操控池)移除——
## 跟解雇(character_roster.gd._dismiss_character())不同的是**不**從 AllCharacterStore
## 移除,死亡角色仍要留在那裡,因為祖譜(FamilyTreeBuilder)是沿現存 Character 物件的
## children/parent/mate 邊走,拔掉物件會讓親族圖斷線。改用 Character.is_dead 標記,祖譜/
## 角色面板靠這個旗標在年齡欄加註「(已故)」。
##
## 死亡導致玩家小隊(PartyStore.party)整隊死光時直接切去 GAME OVER 畫面(見
## Scenes/GameOver/game_over.gd)——跟 System/event/ 底下的 LocationEvent 一樣,
## RefCounted 規則物件本來就會在需要時直接呼叫 NavigationStore.go_to() 驅動場景轉換,
## 不是只有 Scenes 層按鈕處理常式才能切場景。
##
## NEWS/MessageBar 死亡通知只在角色死亡當下還在 CharacterRosterStore(玩家可操控池)裡
## 才發——配偶/小孩本來就不在 roster 裡也一樣要正常判定死亡(is_dead 照樣標記,祖譜照樣
## 顯示「已故」),只是玩家不操控他們,不需要被這則通知打擾(見 CLAUDE.md「老年與死亡」)。

static func kill(character: Character) -> void:
	if character.is_dead:
		return
	character.is_dead = true

	var was_in_roster := CharacterRosterStore.all_characteres.has(character)

	BaseDispatchStore.undispatch_character(character.id)

	if PartyStore.grid != null:
		PartyStore.grid.remove(character)

	if PartyStore.party != null and PartyStore.party.characteres.has(character):
		PartyStore.party.characteres.erase(character)
		PartyStore.party.battle_cost_positions.erase(character)
		if PartyStore.party.leader == character:
			var remaining := PartyStore.party.characteres
			PartyStore.party.leader = remaining[0] if not remaining.is_empty() else null
		if PartyStore.party.characteres.is_empty():
			NavigationStore.go_to("res://Scenes/GameOver/game_over.tscn")

	CharacterRosterStore.all_characteres.erase(character)

	if not was_in_roster:
		return

	MoraleStore.record_event("角色死亡", MoraleStore.DEATH_DELTA)

	var death_text := "%s 因年邁過世了。" % character.full_name
	NewsController.post(death_text, GameEnums.NewsCategory.MAJOR)
	MessageBar.show_message(death_text)
