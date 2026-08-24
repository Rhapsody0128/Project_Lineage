class_name SkillLibrary
extends RefCounted

## 技能總表,薄聚合層:120 條技能依「武器主動/武器被動/通用被動/大將技/血統覺醒技」拆成
## 五個子檔案維護,各自的設計脈絡/命名慣例見各檔案檔頭註解:
## - SkillLibraryWeapon(54 條):六武器各 9 階,武器綁定攻擊為主
## - SkillLibraryWeaponPassive(6 條):六武器各一支反應式被動,不分階級
## - SkillLibraryPassive(18 條):不綁定武器的通用被動,9 階各 2 支
## - SkillLibraryLeader(18 條):只有隊長能用,9 階全隊增益 + 9 階全體敵人減益
## - SkillLibraryBlood(24 條):六大血統各 4 支,限定高血角色
## 技能的數值計算/戰鬥表現一律寫在 SkillEffectLibrary,這裡跟五個子檔案都只負責組裝資料。
## 用 SkillBuilder 鏈式組裝取代舊版 14 個位置參數的建構子——GDScript 沒有具名參數,
## 順序錯了的位置參數會靜默編譯成功、值全部對錯位,鏈式方法呼叫至少方法名拼錯會直接
## 編譯失敗。

static func build() -> Array[Skill]:
	var library: Array[Skill] = []
	library.append_array(SkillLibraryWeapon.build())
	library.append_array(SkillLibraryWeaponPassive.build())
	library.append_array(SkillLibraryPassive.build())
	library.append_array(SkillLibraryLeader.build())
	library.append_array(SkillLibraryBlood.build())
	return library
