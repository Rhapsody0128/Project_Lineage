class_name RhythmChartStore
extends RefCounted

## 12 個生產建築各自的節奏小遊戲譜面,存成專案檔案(res://System/rhythm/charts/
## <BuildingType 小寫名稱>.json),屬於設計內容(比照 BuildingLibrary 的定位——由設計者
## 用 A/B 模式錄製、存檔即寫回專案資料夾,會被 git 追蹤),不是玩家存檔資料,所以不走
## SaveLoadStore 那一套,也不需要 autoload。
##
## 每個建築的 JSON 檔內同時存「常規版」(REGULAR,穩定跟著主拍走)跟「變奏版」
## (VARIATION,切分音/裝飾音較多、更有節奏遊戲感,但音符仍量化在同一套節奏格上,不會
## 跑掉節奏)兩份完整譜面,不是額外欄位——頂層 key 是 variant 字串,value 才是舊版那組
## {"hint_beats":..., "correct_beats":...} 結構。呼叫端一律要帶 variant 參數,沒有預設值
## 藏在背後,避免忘記帶結果悄悄讀到錯的版本。

const VARIANT_REGULAR := "regular"
const VARIANT_VARIATION := "variation"
const VARIANTS: Array[String] = [VARIANT_REGULAR, VARIANT_VARIATION]

const CHART_DIR := "res://System/rhythm/charts/"
## 各建築的正式 BGM 素材(見 Scenes/RhythmGame/rhythm_record_view.gd / rhythm_play_view.gd
## 播放邏輯),檔名同樣採 <BuildingType 大寫名稱>.mp3,還沒有素材的建築呼叫端會用
## ResourceLoader.exists() 檢查,沒有就直接不播 BGM。
const BGM_DIR := "res://Sound/Base/BGM/"
## 各建築測試畫面的角色動作圖(見 Scenes/RhythmGame/rhythm_play_view.gd 的節奏動畫區塊),
## 資料夾同樣採 <BuildingType 大寫名稱>/,底下狀態圖見 RhythmCharacterState。各建築素材
## 不強制完全一致——必要張數是 HOLD/HIT/FIN,加上 HINT 或(HINT1+HINT2)擇一,缺一就不
## 顯示該建築的動畫區塊;HOLD2(待機互換用)、FAIL(玩家敲 MISS 反應用)是可選加分項,
## 有就用、沒有就照舊邏輯(見 RhythmPlayView._load_character_textures()）。
const SPRITE_DIR := "res://Images/Base/"
## 各建築專屬的提示音/點擊音效(見 Scenes/RhythmGame/rhythm_play_view.gd /
## rhythm_record_view.gd),檔名同樣採 <BuildingType 大寫名稱>.mp3,取代舊版全建築共用的
## 暫代 hint.mp3。
const HIT_SFX_DIR := "res://Sound/Base/hit/"


static func _path_for(building_type: GameEnums.BuildingType) -> String:
	return CHART_DIR + _building_key(building_type) + ".json"


static func bgm_path_for(building_type: GameEnums.BuildingType) -> String:
	return BGM_DIR + _building_key(building_type) + ".mp3"


static func hit_sfx_path_for(building_type: GameEnums.BuildingType) -> String:
	return HIT_SFX_DIR + _building_key(building_type) + ".mp3"


static func sprite_path_for(building_type: GameEnums.BuildingType, state: String) -> String:
	return SPRITE_DIR + _building_key(building_type) + "/" + state + ".png"


## 直接吃 GameEnums.BuildingType enum key 的原始大寫拼法(例如 LUMBER_MILL)當檔名/
## 資料夾名——JSON 譜面、BGM、動作圖三種素材路徑一律用同一把 key,不做大小寫轉換。
static func _building_key(building_type: GameEnums.BuildingType) -> String:
	return GameEnums.BuildingType.keys()[building_type]


static func load_chart(building_type: GameEnums.BuildingType, variant: String) -> RhythmChart:
	var data := _load_all_raw(building_type)
	if data.has(variant) and data[variant] is Dictionary:
		return RhythmChart.from_dict(data[variant])
	return RhythmChart.new()


static func save_hint_beats(
	building_type: GameEnums.BuildingType, variant: String, beats: Array[float]
) -> void:
	var chart := load_chart(building_type, variant)
	chart.hint_beats = beats.duplicate()
	_save(building_type, variant, chart)


static func save_correct_beats(
	building_type: GameEnums.BuildingType, variant: String, beats: Array[float]
) -> void:
	var chart := load_chart(building_type, variant)
	chart.correct_beats = beats.duplicate()
	_save(building_type, variant, chart)


## 讀出整份 JSON(所有 variant)的原始 Dictionary,不存在的檔案回傳空字典——內部共用,
## 存檔時要先讀出其他 variant 的資料才不會覆蓋掉。
static func _load_all_raw(building_type: GameEnums.BuildingType) -> Dictionary:
	var path := _path_for(building_type)
	if not FileAccess.file_exists(path):
		return {}

	var file := FileAccess.open(path, FileAccess.READ)
	var text := file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}


static func _save(building_type: GameEnums.BuildingType, variant: String, chart: RhythmChart) -> void:
	DirAccess.make_dir_recursive_absolute(CHART_DIR)
	var data := _load_all_raw(building_type)
	data[variant] = chart.to_dict()
	var file := FileAccess.open(_path_for(building_type), FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
