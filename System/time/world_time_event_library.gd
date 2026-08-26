class_name WorldTimeEventLibrary
extends RefCounted

## 集中管理「遊戲一開始就要註冊」的世界時間固定事件(年紀增長/懷孕/生產/HP 自然回復),
## 比照 SkillLibrary 的靜態方法集中管理寫法。呼叫端(見 world_time_store.gd)只需在
## 遊戲啟動時呼叫一次 register_all(),事件內容(查詢 CharacterRosterStore/NewsController)
## 是在「事件觸發當下」才懶執行,不是註冊當下,所以不用擔心 autoload 初始化順序。

static func register_all(controller: WorldTimeController) -> void:
	
	controller.register_day_event(func(): _regen_hp())

	controller.register_month_event(func(): _roll_new_pregnancies())
	controller.register_month_event(func(): _advance_pregnancies())

	controller.register_year_event(func(): _age_up())


## 每年 1/1:所有角色年紀 +1(見 Character.age_up())。要跑 AllCharacterStore 而不是
## CharacterRosterStore——後者只有「可操控」角色,小孩(_deliver_child() 只註冊進
## AllCharacterStore)、配偶(TownTavernEvent 告白成功後只註冊進 AllCharacterStore)
## 都不在 roster 裡,年紀卻一樣要正常增長。角色剛好跨過 MIN_AGE 那一年順便從
## AllCharacterStore 補進 CharacterRosterStore,讓小孩成年後才能被操控/上場
## (has() 防呆:CharacterController.get_random_character() 生成的角色一律
## >= MIN_AGE,PartyEdit 新增時已經同時進了兩邊,這裡不會重複加)。已死亡的角色
## (Character.is_dead)直接跳過整段——不增齡、不重複判定衰老/死亡(見 CLAUDE.md
## 「老年與死亡」)。
static func _age_up() -> void:
	for character in AllCharacterStore.all_characteres:
		if character.is_dead:
			continue
		character.age_up()
		if character.age == CharacterController.MIN_AGE and CharacterRosterStore.try_add(character):
			NewsController.post("%s 成年了。" % character.full_name, GameEnums.NewsCategory.MAJOR)
		_process_aging(character)


## 年紀跨過衰老線(AgingRule.get_aging_line(),受 CLINIC 等級影響)第一次掛上衰老特性
## (全素質 -30%,見 AgingRule.create_aging_trait());之後每年只要還在衰老線以上,
## 都依 AgingRule.get_death_chance_percent() 骰一次是否過世
## (CharacterDeathController.kill() 負責清乾淨小隊/根據地派遣再移出角色列)。
##
## 素質特性一律照套用,但只有目前還在 CharacterRosterStore(玩家可操控池)裡的角色才發
## NEWS/MessageBar 通知——配偶/小孩本來就不在 roster 裡也一樣要正常衰老,但玩家不會操控
## 他們,不需要被這些通知打擾(見 CLAUDE.md「老年與死亡」)。
static func _process_aging(character: Character) -> void:
	if not AgingRule.is_aged(character):
		return
	if not AgingRule.has_aging_trait(character):
		character.traits.append(AgingRule.create_aging_trait())
		if CharacterRosterStore.all_characteres.has(character):
			var aging_text := "%s 已進入衰老期，各項素質開始衰退。" % character.full_name
			NewsController.post(aging_text, GameEnums.NewsCategory.MAJOR)
			MessageBar.show_message(aging_text)
	if AgingRule.roll_death(character):
		CharacterDeathController.kill(character)



## 每月:符合資格(女性/已婚/未懷孕)的角色依 PregnancyRule.get_pregnancy_chance_percent()
## 機率骰懷孕——基準值 + 依子女數量指數衰減 + 父母任一方衰老直接歸零(見該函式註解),
## 不是每個月必中。判定對象用 PregnancyRule.resolve_pregnancy_candidate() 從配偶雙方解出,
## 不能只看 character 本人——配偶可能不在 CharacterRosterStore 裡(見該函式註解)。
## processed_ids 避免雙方剛好都在 roster 時,同一對配偶被兩個迴圈疊代各骰一次。
static func _roll_new_pregnancies() -> void:
	var processed_ids: Dictionary = {}
	for character in CharacterRosterStore.all_characteres:
		var wife := PregnancyRule.resolve_pregnancy_candidate(character)
		if wife == null or processed_ids.has(wife.id):
			continue
		processed_ids[wife.id] = true
		if PregnancyRule.is_eligible(wife) and PregnancyRule.roll_pregnancy(wife):
			wife.start_pregnancy()
			var pregnancy_text := "%s 懷孕了。" % wife.full_name
			NewsController.post(pregnancy_text, GameEnums.NewsCategory.MAJOR)
			MessageBar.show_message(pregnancy_text)


## 每月:懷孕中的角色累積月數(見 Character.advance_pregnancy()),滿了就產下孩子。
## 剛懷孕當月與 _roll_new_pregnancies() 同一個月邊界觸發,即計入第 1 個月,是刻意的簡化行為。
## 判定對象一樣要用 PregnancyRule.resolve_pregnancy_candidate() 從配偶雙方解出(理由同
## _roll_new_pregnancies()),否則懷孕的配偶不在 roster 時,懷孕月數永遠不會推進。
##
## 角色總容量(見 BaseBuildingProgressStore.get_character_capacity())已滿時,月數繼續
## 累積但不產下孩子——advance_pregnancy() 已經回傳 true(滿月數),不呼叫 _deliver_child()
## 就不會重置 is_pregnant/pregnancy_months,下個月會再檢查一次容量,直到住宅騰出空間為止。
static func _advance_pregnancies() -> void:
	var processed_ids: Dictionary = {}
	for character in CharacterRosterStore.all_characteres:
		var wife := PregnancyRule.resolve_pregnancy_candidate(character)
		if wife == null or processed_ids.has(wife.id):
			continue
		processed_ids[wife.id] = true
		if not wife.is_pregnant or not wife.advance_pregnancy():
			continue
		if AllCharacterStore.all_characteres.size() < BaseBuildingProgressStore.get_character_capacity():
			_deliver_child(wife)


## 產下孩子(見 Character.give_birth()),只註冊進 AllCharacterStore(讓孩子開始
## 隨世界時間長大),不直接進 CharacterRosterStore——小孩未滿 MIN_AGE 前不能操控/
## 上場,要等 _age_up() 偵測到年紀跨過 MIN_AGE 才會補進 roster。並寫入 NEWS。呼叫端已經
## 確認過角色總容量還有空位(見 _advance_pregnancies()),這裡的 register() 必定成功。
## 同時排隊切去命名+留學國家場景(見 CLAUDE.md「新生兒命名與留學」),不擋 register() 本身。
static func _deliver_child(mother: Character) -> void:
	var child := mother.give_birth()
	AllCharacterStore.register(child)
	NewsController.post("%s 誕下了孩子 %s。" % [mother.full_name, child.full_name], GameEnums.NewsCategory.MAJOR)
	LifeEventQueueStore.queue_child(child)


## 每天:玩家擁有的所有角色 HP 回復(見 Character.regen_daily_hp(),取代舊版「僅出戰隊伍、
## 大地圖移動時逐幀累積回 30/天」機制)。回復量 = 基準值 3 + 醫療所目前等級(未建醫療所
## 時等同 Lv0,回復量維持原本的 3,不會讓沒蓋醫療所的玩家倒退)+ 休息中額外加成 10
## (MapSessionStore.is_resting,見 Scenes/Map/map.gd 的「休息」機制——離開休息狀態
## 當天就立刻退回沒有加成的回復量,不是「休息當天結算完才生效」)。
static func _regen_hp() -> void:
	var amount := Character.DAILY_HP_REGEN + BaseBuildingProgressStore.get_level(GameEnums.BuildingType.CLINIC)
	if MapSessionStore.is_resting:
		amount += Character.RESTING_HP_REGEN_BONUS
	for character in CharacterRosterStore.all_characteres:
		character.regen_daily_hp(amount)
