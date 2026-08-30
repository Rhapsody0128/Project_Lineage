class_name Trait
extends RefCounted

var id: String
var name: String
var description: String
var polarity: int
## 形容詞形態(例如「勇猛」→「勇猛的」),角色顯示稱號時(見 Character.title_full_name)
## 用出生第一個特性(traits[0])的這個欄位當人物形容詞,拼在爵位稱號前面。獨立欄位
## 而非直接在 name 後面加「的」字串拼接,方便之後遇到不規則詞形時個別覆寫。
var title_adjective: String
## 全素質連乘係數(1.0 = 無效果),見 Character._trait_stat_multiplier()。目前只有
## AgingRule 建立的衰老特性會設成非 1.0,其餘特性維持預設值不影響素質計算。
var stat_multiplier: float = 1.0
## 是否為 AgingRule 建立的衰老特性——用旗標識別，不比對 name 字串（比照
## Character.knows_guard_skill() 用旗標而非顯示名稱字串比對的既有慣例，改名稱/翻譯
## 不會悄悄讓判斷失效）。
var is_aging: bool = false

func _init(p_name: String, p_description: String, p_polarity: int, p_title_adjective: String) -> void:
	id = Util.generate_uuid()
	name = p_name
	description = p_description
	polarity = p_polarity
	title_adjective = p_title_adjective
