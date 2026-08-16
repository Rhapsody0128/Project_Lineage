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


## 每年 1/1:所有玩家角色年紀 +1(見 Character.age_up())
static func _age_up() -> void:
	for character in CharacterRosterStore.all_characteres:
		character.age_up()


## 每月:符合資格(女性/已婚/未懷孕)的角色機率懷孕(目前 100%),寫入 NEWS
static func _roll_new_pregnancies() -> void:
	for character in CharacterRosterStore.all_characteres:
		if PregnancyRule.is_eligible(character) and PregnancyRule.roll_pregnancy():
			character.start_pregnancy()
			NewsController.post("%s 懷孕了。" % character.full_name)


## 每月:懷孕中的角色累積月數(見 Character.advance_pregnancy()),滿了就產下孩子。
## 剛懷孕當月與 _roll_new_pregnancies() 同一個月邊界觸發,即計入第 1 個月,是刻意的簡化行為。
static func _advance_pregnancies() -> void:
	for character in CharacterRosterStore.all_characteres:
		if character.is_pregnant and character.advance_pregnancy():
			_deliver_child(character)


## 產下孩子(見 Character.give_birth()),加入 CharacterRosterStore(讓孩子成為可用角色),
## 並寫入 NEWS
static func _deliver_child(mother: Character) -> void:
	var child := mother.give_birth()
	CharacterRosterStore.all_characteres.append(child)
	NewsController.post("%s 誕下了孩子 %s。" % [mother.full_name, child.full_name])


## 每天:玩家擁有的所有角色 HP +50(見 Character.regen_daily_hp(),取代舊版「僅出戰隊伍、
## 大地圖移動時逐幀累積回 30/天」機制)
static func _regen_hp() -> void:
	for character in CharacterRosterStore.all_characteres:
		character.regen_daily_hp()
