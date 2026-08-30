class_name WeddingEvent
extends LocationEvent

## 婚禮儀式的實際演出入口——告白流程(TownTavernEvent)/聯姻流程(BaseMarriageEvent)
## 接受成功後不再立刻結婚,改呼叫 WeddingQueueStore.queue_wedding() 記錄下來,等 30 天
## (WeddingQueueStore.DELAY_DAYS)後由該 store 的每日倒數呼叫這裡的 trigger()——真正
## 寫入 Character.marry()、播婚禮宣誓 Dialogue(WeddingCeremonyDialogue)、彈新配偶的
## CharacterPanel、發結婚 MESSAGE(News/MessageBar/晨曦度)全部集中在這裡,兩邊呼叫端
## 不再各自重複一份。
##
## 觸發當下玩家可能人在任何一個掛了 HeaderBar 的場景(大地圖/根據地/城鎮……)——比照
## WorldTimeEventLibrary._deliver_child()/CharacterDeathController.kill() 既有慣例,
## RefCounted 規則物件本來就會在需要時直接驅動場景轉換,不等玩家點按鈕。跟那兩個不同的是
## 這裡播完要回到原本場景(不是切去獨立的死亡/命名畫面然後由玩家決定去哪),所以用
## NavigationStore.push_return_scene_path() 手動記一筆,播完呼叫 go_back() 回去——
## goto_dialogue() 本身是中繼場景不會自動記錄(見 NavigationStore 開頭註解)。
##
## return_scene_path 由呼叫端(WeddingQueueStore)傳入,不在這裡自己讀
## tree.current_scene——SceneTree.change_scene_to_file() 是 deferred 的,同一天有好幾場
## 婚禮排隊時,下一場的 trigger() 是在上一場 go_back() 的 deferred 場景切換「還沒真的生效」
## 那一刻就被同步呼叫(見 WeddingQueueStore._process_next_if_idle() 的收尾 callback),這裡
## 讀到的 tree.current_scene 會是還沒被換掉的 dialogue_box.tscn,錯誤地把它推進歷史堆疊。
## WeddingQueueStore 只在保證安全的時機點(_on_day_passed(),只會被 HeaderBar._process()
## 呼叫,current_scene 當下一定是大地圖/根據地本體)讀一次、整批共用同一個值,才不會踩到
## 這個陷阱。
##
## on_done 選填:播完(含彈 CharacterPanel、發訊息)之後呼叫一次,供 WeddingQueueStore
## 串接「這天還有下一場婚禮排隊」的收尾,不需要撐過存讀檔(每次都是同一個 session 內
## 現建的 closure,不會被序列化,見該檔案)。


static func trigger(own_character: Character, spouse_character: Character, announcement_text: String, return_scene_path: String, on_done: Callable = Callable()) -> void:
	var event := WeddingEvent.new()
	event._start(own_character, spouse_character, announcement_text, return_scene_path, on_done)


func _start(own_character: Character, spouse_character: Character, announcement_text: String, return_scene_path: String, on_done: Callable) -> void:
	# 暫停時間已經統一收進 LocationEvent.goto_dialogue()(見該檔案),這裡不用重複設定。
	if not return_scene_path.is_empty():
		NavigationStore.push_return_scene_path(return_scene_path)

	own_character.marry(spouse_character)

	goto_dialogue(WeddingCeremonyDialogue.build(own_character, spouse_character), "", func() -> void:
		CharacterPanel.open_for_character(spouse_character)
		NewsController.post(announcement_text, GameEnums.NewsCategory.MAJOR)
		MessageBar.show_message(announcement_text)
		MoraleStore.record_event("角色結婚", MoraleStore.MARRIAGE_DELTA)
		NavigationStore.go_back()
		if on_done.is_valid():
			on_done.call()
	)
