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
## >= MIN_AGE,PartyEdit 新增時已經同時進了兩邊,這裡不會重複加)。
static func _age_up() -> void:
	for character in AllCharacterStore.all_characteres:
		character.age_up()
		if character.age == CharacterController.MIN_AGE and not CharacterRosterStore.all_characteres.has(character):
			CharacterRosterStore.all_characteres.append(character)
			NewsController.post("%s 成年了。" % character.full_name)



## 每月:符合資格(女性/已婚/未懷孕)的角色機率懷孕(目前 100%),寫入 NEWS。判定對象
## 用 PregnancyRule.resolve_pregnancy_candidate() 從配偶雙方解出,不能只看 character 本人
## ——配偶可能不在 CharacterRosterStore 裡(見該函式註解)。processed_ids 避免雙方剛好都
## 在 roster 時,同一對配偶被兩個迴圈疊代各骰一次。
static func _roll_new_pregnancies() -> void:
	var processed_ids: Dictionary = {}
	for character in CharacterRosterStore.all_characteres:
		var wife := PregnancyRule.resolve_pregnancy_candidate(character)
		if wife == null or processed_ids.has(wife.id):
			continue
		processed_ids[wife.id] = true
		if PregnancyRule.is_eligible(wife) and PregnancyRule.roll_pregnancy():
			wife.start_pregnancy()
			NewsController.post("%s 懷孕了。" % wife.full_name)


## 每月:懷孕中的角色累積月數(見 Character.advance_pregnancy()),滿了就產下孩子。
## 剛懷孕當月與 _roll_new_pregnancies() 同一個月邊界觸發,即計入第 1 個月,是刻意的簡化行為。
## 判定對象一樣要用 PregnancyRule.resolve_pregnancy_candidate() 從配偶雙方解出(理由同
## _roll_new_pregnancies()),否則懷孕的配偶不在 roster 時,懷孕月數永遠不會推進。
static func _advance_pregnancies() -> void:
	var processed_ids: Dictionary = {}
	for character in CharacterRosterStore.all_characteres:
		var wife := PregnancyRule.resolve_pregnancy_candidate(character)
		if wife == null or processed_ids.has(wife.id):
			continue
		processed_ids[wife.id] = true
		if wife.is_pregnant and wife.advance_pregnancy():
			_deliver_child(wife)


## 產下孩子(見 Character.give_birth()),只註冊進 AllCharacterStore(讓孩子開始
## 隨世界時間長大),不直接進 CharacterRosterStore——小孩未滿 MIN_AGE 前不能操控/
## 上場,要等 _age_up() 偵測到年紀跨過 MIN_AGE 才會補進 roster。並寫入 NEWS。
static func _deliver_child(mother: Character) -> void:
	var child := mother.give_birth()
	AllCharacterStore.register(child)
	NewsController.post("%s 誕下了孩子 %s。" % [mother.full_name, child.full_name])


## 每天:玩家擁有的所有角色 HP +3(見 Character.regen_daily_hp(),取代舊版「僅出戰隊伍、
## 大地圖移動時逐幀累積回 30/天」機制)
static func _regen_hp() -> void:
	for character in CharacterRosterStore.all_characteres:
		character.regen_daily_hp()
