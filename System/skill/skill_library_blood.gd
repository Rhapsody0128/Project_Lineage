class_name SkillLibraryBlood
extends RefCounted

## 血統覺醒技,六大血統(GameEnums.BloodlineNation)各 4 支,只有高血(NOBLE)角色才有機率
## 習得(SkillBuilder.requires_bloodline() 預設 NOBLE,見 Character.can_use_skill() 的血統
## 守門)。不綁定武器,素質組合依血統風格設計,部分是雙屬性乘區(見
## SkillEffectLibrary._generic_attack_value())——雙修的價值是「上限更高、但建置要求更
## 苛刻」,不是無條件比單屬性技能強。rank 統一填 F(不代表取得難度,取得門檻由
## required_bloodline_rank 決定,不是靠 rank 抽選稀有度)。
##
## 「攏絡」(魅惑倒戈)尚未實作戰場狀態轉換,豹瞳魅惑原本設計是攏絡,這裡先用恐懼代替
## (跟亂軍之聲同樣的暫代決定,見 SkillLibraryLeader 檔頭註解),等攏絡的實際效果做出來
## 後再換掉。部分描述裡「並且...」的第二個效果(熊魂不倒的本回合減傷、龍血覺醒的技能
## 權重提升)設計表只給了一組數值,沒有另外的門檻/比例可用,先簡化成單一效果(素質增益),
## 不臆測一個沒被指定的數字。

static func build() -> Array[Skill]:
	var skills: Array[Skill] = []
	skills.append_array(_lion_skills())
	skills.append_array(_eagle_skills())
	skills.append_array(_leopard_skills())
	skills.append_array(_bear_skills())
	skills.append_array(_dragon_skills())
	skills.append_array(_deer_skills())
	return skills


static func _lion_skills() -> Array[Skill]:
	var skills: Array[Skill] = []

	skills.append(SkillBuilder.new()
		.name("獅子威怒")
		.description("王者怒吼震盪範圍敵人,受創目標同時陷入恐懼")
		.rank(GameEnums.RankType.A)
		.skill_range(0).area_shape(GameEnums.AreaShape.RADIUS).area_size(2)
		.effect_stat(GameEnums.PotentialType.STRENGTH)
		.skill_type(GameEnums.SkillType.ATTACK)
		.bind_weapon(GameEnums.NO_WEAPON_BINDING)
		.requires_bloodline(GameEnums.BloodlineNation.LION)
		.base_chance(30.0).skill_ratio(2.8).duration_rounds(2)
		.mechanics([GameEnums.SkillMechanic.FEAR])
		.action(Callable(SkillEffectLibrary, "generic_attack_with_mechanic"))
		.build())

	skills.append(SkillBuilder.new()
		.name("血獅王座")
		.description("血統中流淌的君王氣度感染全軍,提升全隊力量")
		.rank(GameEnums.RankType.A)
		.skill_range(0).area_shape(GameEnums.AreaShape.ALL_ALLIES).area_size(1)
		.effect_stat(GameEnums.PotentialType.STRENGTH)
		.skill_type(GameEnums.SkillType.BUFF)
		.bind_weapon(GameEnums.NO_WEAPON_BINDING)
		.requires_bloodline(GameEnums.BloodlineNation.LION)
		.base_chance(28.0).skill_ratio(0.14).duration_rounds(3)
		.buffed_stats([GameEnums.PotentialType.STRENGTH])
		.action(Callable(SkillEffectLibrary, "stat_buff"))
		.build())

	skills.append(SkillBuilder.new()
		.name("魔獅劍氣")
		.description("王者血脈中蘊藏著超越蠻力的智慧,劍鋒纏繞無形魔力直取要害——同時吃智慧與力量,雙修者的輸出遠超一般武器技,但沒有對應素質基礎就發揮不出全部威力")
		.rank(GameEnums.RankType.A)
		.skill_range(3).area_shape(GameEnums.AreaShape.SINGLE).area_size(1)
		.effect_stat(GameEnums.PotentialType.INTELLIGENCE)
		.skill_type(GameEnums.SkillType.ATTACK)
		.bind_weapon(GameEnums.NO_WEAPON_BINDING)
		.requires_bloodline(GameEnums.BloodlineNation.LION)
		.base_chance(26.0).skill_ratio(2.8).secondary_stat(GameEnums.PotentialType.STRENGTH, 1.2)
		.action(Callable(SkillEffectLibrary, "generic_attack"))
		.build())

	skills.append(SkillBuilder.new()
		.name("獅心庇護")
		.description("獅族庇護幼獸的本能延伸至戰場,以體質與精神雙重灌注治癒全軍,效果遠超一般單一素質的治療技")
		.rank(GameEnums.RankType.A)
		.skill_range(0).area_shape(GameEnums.AreaShape.ALL_ALLIES).area_size(1)
		.effect_stat(GameEnums.PotentialType.VITALITY)
		.skill_type(GameEnums.SkillType.HEAL)
		.bind_weapon(GameEnums.NO_WEAPON_BINDING)
		.requires_bloodline(GameEnums.BloodlineNation.LION)
		.base_chance(28.0).skill_ratio(1.6).secondary_stat(GameEnums.PotentialType.MENTALITY, 1.6)
		.action(Callable(SkillEffectLibrary, "heal"))
		.build())

	return skills


static func _eagle_skills() -> Array[Skill]:
	var skills: Array[Skill] = []

	skills.append(SkillBuilder.new()
		.name("天穹絕殺")
		.description("鷹眼鎖定弱點,居高臨下的致命俯衝一擊")
		.rank(GameEnums.RankType.A)
		.skill_range(4).area_shape(GameEnums.AreaShape.SINGLE).area_size(1)
		.effect_stat(GameEnums.PotentialType.DEXTERITY)
		.skill_type(GameEnums.SkillType.ATTACK)
		.bind_weapon(GameEnums.NO_WEAPON_BINDING)
		.requires_bloodline(GameEnums.BloodlineNation.EAGLE)
		.base_chance(28.0).skill_ratio(3.4)
		.action(Callable(SkillEffectLibrary, "generic_attack"))
		.build())

	skills.append(SkillBuilder.new()
		.name("疾風之眼")
		.description("血脈中與生俱來的銳利視野,全隊靈巧提升")
		.rank(GameEnums.RankType.A)
		.skill_range(0).area_shape(GameEnums.AreaShape.ALL_ALLIES).area_size(1)
		.effect_stat(GameEnums.PotentialType.DEXTERITY)
		.skill_type(GameEnums.SkillType.BUFF)
		.bind_weapon(GameEnums.NO_WEAPON_BINDING)
		.requires_bloodline(GameEnums.BloodlineNation.EAGLE)
		.base_chance(30.0).skill_ratio(0.12).duration_rounds(3)
		.buffed_stats([GameEnums.PotentialType.DEXTERITY])
		.action(Callable(SkillEffectLibrary, "stat_buff"))
		.build())

	skills.append(SkillBuilder.new()
		.name("鷹眼識破")
		.description("鷹血脈化作銳利的洞察與直覺,靈巧與智慧兩相匯聚成無視防禦的致命一擊,雙修者才吃得到全部輸出")
		.rank(GameEnums.RankType.A)
		.skill_range(4).area_shape(GameEnums.AreaShape.SINGLE).area_size(1)
		.effect_stat(GameEnums.PotentialType.DEXTERITY)
		.skill_type(GameEnums.SkillType.ATTACK)
		.bind_weapon(GameEnums.NO_WEAPON_BINDING)
		.requires_bloodline(GameEnums.BloodlineNation.EAGLE)
		.base_chance(26.0).skill_ratio(2.2).secondary_stat(GameEnums.PotentialType.INTELLIGENCE, 1.8)
		.mechanics([GameEnums.SkillMechanic.ARMOR_PIERCE])
		.action(Callable(SkillEffectLibrary, "generic_attack_with_mechanic"))
		.build())

	skills.append(SkillBuilder.new()
		.name("振翅齊心")
		.description("鷹群振翅盤旋,力量與體質隨氣流一同匯聚全身")
		.rank(GameEnums.RankType.A)
		.skill_range(0).area_shape(GameEnums.AreaShape.ALL_ALLIES).area_size(1)
		.effect_stat(GameEnums.PotentialType.STRENGTH)
		.skill_type(GameEnums.SkillType.BUFF)
		.bind_weapon(GameEnums.NO_WEAPON_BINDING)
		.requires_bloodline(GameEnums.BloodlineNation.EAGLE)
		.base_chance(28.0).skill_ratio(0.16).duration_rounds(3)
		.buffed_stats([GameEnums.PotentialType.STRENGTH, GameEnums.PotentialType.VITALITY])
		.action(Callable(SkillEffectLibrary, "stat_buff"))
		.build())

	return skills


static func _leopard_skills() -> Array[Skill]:
	var skills: Array[Skill] = []

	skills.append(SkillBuilder.new()
		.name("影豹連殺")
		.description("潛伏後瞬間暴衝,連續突刺兩次且皆無視部分防禦")
		.rank(GameEnums.RankType.A)
		.skill_range(1).area_shape(GameEnums.AreaShape.SINGLE).area_size(1)
		.effect_stat(GameEnums.PotentialType.AGILITY)
		.skill_type(GameEnums.SkillType.ATTACK)
		.bind_weapon(GameEnums.NO_WEAPON_BINDING)
		.requires_bloodline(GameEnums.BloodlineNation.LEOPARD)
		.base_chance(32.0).skill_ratio(2.4).multi_strike(2)
		.mechanics([GameEnums.SkillMechanic.ARMOR_PIERCE])
		.action(Callable(SkillEffectLibrary, "generic_attack_with_mechanic"))
		.build())

	skills.append(SkillBuilder.new()
		.name("豹魂疾走")
		.description("血統中的敏捷本能喚醒全軍,全隊敏捷提升")
		.rank(GameEnums.RankType.A)
		.skill_range(0).area_shape(GameEnums.AreaShape.ALL_ALLIES).area_size(1)
		.effect_stat(GameEnums.PotentialType.AGILITY)
		.skill_type(GameEnums.SkillType.BUFF)
		.bind_weapon(GameEnums.NO_WEAPON_BINDING)
		.requires_bloodline(GameEnums.BloodlineNation.LEOPARD)
		.base_chance(30.0).skill_ratio(0.14).duration_rounds(3)
		.buffed_stats([GameEnums.PotentialType.AGILITY])
		.action(Callable(SkillEffectLibrary, "stat_buff"))
		.build())

	skills.append(SkillBuilder.new()
		.name("豹瞳魅惑") # 原設計為攏絡,暫以恐懼代替,見檔頭註解
		.description("潛藏暗處的豹瞳散發攝人心魄的魅惑,精神魅力與矯健身手雙重疊加,重創之餘更擾亂敵人意志")
		.rank(GameEnums.RankType.A)
		.skill_range(1).area_shape(GameEnums.AreaShape.SINGLE).area_size(1)
		.effect_stat(GameEnums.PotentialType.MENTALITY)
		.skill_type(GameEnums.SkillType.ATTACK)
		.bind_weapon(GameEnums.NO_WEAPON_BINDING)
		.requires_bloodline(GameEnums.BloodlineNation.LEOPARD)
		.base_chance(28.0).skill_ratio(2.0).secondary_stat(GameEnums.PotentialType.AGILITY, 1.4).duration_rounds(1)
		.mechanics([GameEnums.SkillMechanic.FEAR])
		.action(Callable(SkillEffectLibrary, "generic_attack_with_mechanic"))
		.build())

	skills.append(SkillBuilder.new()
		.name("豹魂堅韌")
		.description("看似輕盈的豹族血脈,其實也繼承了荒野求生的堅韌,同時強化體質與敏捷")
		.rank(GameEnums.RankType.A)
		.skill_range(0).area_shape(GameEnums.AreaShape.ALL_ALLIES).area_size(1)
		.effect_stat(GameEnums.PotentialType.VITALITY)
		.skill_type(GameEnums.SkillType.BUFF)
		.bind_weapon(GameEnums.NO_WEAPON_BINDING)
		.requires_bloodline(GameEnums.BloodlineNation.LEOPARD)
		.base_chance(28.0).skill_ratio(0.16).duration_rounds(3)
		.buffed_stats([GameEnums.PotentialType.VITALITY, GameEnums.PotentialType.AGILITY])
		.action(Callable(SkillEffectLibrary, "stat_buff"))
		.build())

	return skills


static func _bear_skills() -> Array[Skill]:
	var skills: Array[Skill] = []

	skills.append(SkillBuilder.new()
		.name("熊霸碎地")
		.description("揮動蠻力十足的臂膀重重砸下,使周遭敵人體質下降")
		.rank(GameEnums.RankType.A)
		.skill_range(0).area_shape(GameEnums.AreaShape.RADIUS).area_size(2)
		.effect_stat(GameEnums.PotentialType.VITALITY)
		.skill_type(GameEnums.SkillType.ATTACK)
		.bind_weapon(GameEnums.NO_WEAPON_BINDING)
		.requires_bloodline(GameEnums.BloodlineNation.BEAR)
		.base_chance(28.0).skill_ratio(2.6).duration_rounds(2)
		.action(Callable(SkillEffectLibrary, "generic_attack_with_stat_debuff").bind(
			[GameEnums.PotentialType.VITALITY] as Array[int], -0.15
		))
		.build())

	skills.append(SkillBuilder.new()
		.name("熊魂不倒")
		.description("血脈中沉睡的熊魂甦醒,提升全隊體質")
		.rank(GameEnums.RankType.A)
		.skill_range(0).area_shape(GameEnums.AreaShape.ALL_ALLIES).area_size(1)
		.effect_stat(GameEnums.PotentialType.VITALITY)
		.skill_type(GameEnums.SkillType.BUFF)
		.bind_weapon(GameEnums.NO_WEAPON_BINDING)
		.requires_bloodline(GameEnums.BloodlineNation.BEAR)
		.base_chance(28.0).skill_ratio(0.12).duration_rounds(1)
		.buffed_stats([GameEnums.PotentialType.VITALITY])
		.action(Callable(SkillEffectLibrary, "stat_buff"))
		.build())

	skills.append(SkillBuilder.new()
		.name("熊智破敵")
		.description("沉穩的熊族血脈蘊藏出乎意料的智慧,結合厚實體魄算準要害,雙修者的一擊遠比單一素質的技能致命")
		.rank(GameEnums.RankType.A)
		.skill_range(3).area_shape(GameEnums.AreaShape.SINGLE).area_size(1)
		.effect_stat(GameEnums.PotentialType.INTELLIGENCE)
		.skill_type(GameEnums.SkillType.ATTACK)
		.bind_weapon(GameEnums.NO_WEAPON_BINDING)
		.requires_bloodline(GameEnums.BloodlineNation.BEAR)
		.base_chance(26.0).skill_ratio(2.4).secondary_stat(GameEnums.PotentialType.VITALITY, 1.6)
		.mechanics([GameEnums.SkillMechanic.GUARANTEED_CRIT])
		.action(Callable(SkillEffectLibrary, "generic_attack_with_mechanic"))
		.build())

	skills.append(SkillBuilder.new()
		.name("熊裔沉毅")
		.description("熊裔與生俱來的沉穩感染全軍,同時堅定心志與體魄")
		.rank(GameEnums.RankType.A)
		.skill_range(0).area_shape(GameEnums.AreaShape.ALL_ALLIES).area_size(1)
		.effect_stat(GameEnums.PotentialType.MENTALITY)
		.skill_type(GameEnums.SkillType.BUFF)
		.bind_weapon(GameEnums.NO_WEAPON_BINDING)
		.requires_bloodline(GameEnums.BloodlineNation.BEAR)
		.base_chance(28.0).skill_ratio(0.16).duration_rounds(3)
		.buffed_stats([GameEnums.PotentialType.MENTALITY, GameEnums.PotentialType.VITALITY])
		.action(Callable(SkillEffectLibrary, "stat_buff"))
		.build())

	return skills


static func _dragon_skills() -> Array[Skill]:
	var skills: Array[Skill] = []

	skills.append(SkillBuilder.new()
		.name("真龍降世")
		.description("龍血激昂咆哮而出,凜冽寒氣重創範圍敵人並使其封印")
		.rank(GameEnums.RankType.A)
		.skill_range(3).area_shape(GameEnums.AreaShape.RADIUS).area_size(3)
		.effect_stat(GameEnums.PotentialType.INTELLIGENCE)
		.skill_type(GameEnums.SkillType.ATTACK)
		.bind_weapon(GameEnums.NO_WEAPON_BINDING)
		.requires_bloodline(GameEnums.BloodlineNation.DRAGON)
		.base_chance(26.0).skill_ratio(2.6).duration_rounds(1)
		.mechanics([GameEnums.SkillMechanic.SEAL])
		.action(Callable(SkillEffectLibrary, "generic_attack_with_mechanic"))
		.build())

	skills.append(SkillBuilder.new()
		.name("龍血覺醒")
		.description("尊貴的真龍血統覺醒,力量與智慧同時提升")
		.rank(GameEnums.RankType.A)
		.skill_range(0).area_shape(GameEnums.AreaShape.ALL_ALLIES).area_size(1)
		.effect_stat(GameEnums.PotentialType.STRENGTH)
		.skill_type(GameEnums.SkillType.BUFF)
		.bind_weapon(GameEnums.NO_WEAPON_BINDING)
		.requires_bloodline(GameEnums.BloodlineNation.DRAGON)
		.base_chance(28.0).skill_ratio(0.10).duration_rounds(2)
		.buffed_stats([GameEnums.PotentialType.STRENGTH, GameEnums.PotentialType.INTELLIGENCE])
		.action(Callable(SkillEffectLibrary, "stat_buff"))
		.build())

	skills.append(SkillBuilder.new()
		.name("龍爪裂地")
		.description("真龍血脈偶爾捨棄法術直接以爪牙貫穿敵陣,爪尖仍纏繞著魔力,力量與智慧兼修者才擋得住這一擊的全部重量")
		.rank(GameEnums.RankType.A)
		.skill_range(1).area_shape(GameEnums.AreaShape.SINGLE).area_size(1)
		.effect_stat(GameEnums.PotentialType.STRENGTH)
		.skill_type(GameEnums.SkillType.ATTACK)
		.bind_weapon(GameEnums.NO_WEAPON_BINDING)
		.requires_bloodline(GameEnums.BloodlineNation.DRAGON)
		.base_chance(24.0).skill_ratio(2.4).secondary_stat(GameEnums.PotentialType.INTELLIGENCE, 1.6)
		.action(Callable(SkillEffectLibrary, "generic_attack"))
		.build())

	skills.append(SkillBuilder.new()
		.name("龍威震懾")
		.description("龍嘯震盪心神,尊貴的智慧強化了這份威壓,精神與智慧雙修者能讓敵人陷入更深的恐懼")
		.rank(GameEnums.RankType.A)
		.skill_range(3).area_shape(GameEnums.AreaShape.RADIUS).area_size(2)
		.effect_stat(GameEnums.PotentialType.MENTALITY)
		.skill_type(GameEnums.SkillType.ATTACK)
		.bind_weapon(GameEnums.NO_WEAPON_BINDING)
		.requires_bloodline(GameEnums.BloodlineNation.DRAGON)
		.base_chance(24.0).skill_ratio(2.0).secondary_stat(GameEnums.PotentialType.INTELLIGENCE, 1.4).duration_rounds(1)
		.mechanics([GameEnums.SkillMechanic.FEAR])
		.action(Callable(SkillEffectLibrary, "generic_attack_with_mechanic"))
		.build())

	return skills


static func _deer_skills() -> Array[Skill]:
	var skills: Array[Skill] = []

	skills.append(SkillBuilder.new()
		.name("鹿靈庇世")
		.description("高原鹿靈血脈帶來大地的祝福,治癒全軍並清除一項異常")
		.rank(GameEnums.RankType.A)
		.skill_range(0).area_shape(GameEnums.AreaShape.ALL_ALLIES).area_size(1)
		.effect_stat(GameEnums.PotentialType.MENTALITY)
		.skill_type(GameEnums.SkillType.HEAL)
		.bind_weapon(GameEnums.NO_WEAPON_BINDING)
		.requires_bloodline(GameEnums.BloodlineNation.DEER)
		.base_chance(30.0).skill_ratio(2.2)
		.action(Callable(SkillEffectLibrary, "heal_with_cleanse"))
		.build())

	skills.append(SkillBuilder.new()
		.name("森靈震魂")
		.description("靈鹿血統釋放的精神波動,重創敵人並使其治療效果降低")
		.rank(GameEnums.RankType.A)
		.skill_range(2).area_shape(GameEnums.AreaShape.RADIUS).area_size(2)
		.effect_stat(GameEnums.PotentialType.MENTALITY)
		.skill_type(GameEnums.SkillType.ATTACK)
		.bind_weapon(GameEnums.NO_WEAPON_BINDING)
		.requires_bloodline(GameEnums.BloodlineNation.DEER)
		.base_chance(26.0).skill_ratio(2.4).duration_rounds(2)
		.mechanics([GameEnums.SkillMechanic.HEAL_DOWN])
		.action(Callable(SkillEffectLibrary, "generic_attack_with_mechanic"))
		.build())

	skills.append(SkillBuilder.new()
		.name("鹿蹄疾行")
		.description("看似溫馴的鹿群,奔跑速度與旺盛生命力絲毫不輸猛獸,同時強化敏捷與體質")
		.rank(GameEnums.RankType.A)
		.skill_range(0).area_shape(GameEnums.AreaShape.ALL_ALLIES).area_size(1)
		.effect_stat(GameEnums.PotentialType.AGILITY)
		.skill_type(GameEnums.SkillType.BUFF)
		.bind_weapon(GameEnums.NO_WEAPON_BINDING)
		.requires_bloodline(GameEnums.BloodlineNation.DEER)
		.base_chance(28.0).skill_ratio(0.16).duration_rounds(3)
		.buffed_stats([GameEnums.PotentialType.AGILITY, GameEnums.PotentialType.VITALITY])
		.action(Callable(SkillEffectLibrary, "stat_buff"))
		.build())

	skills.append(SkillBuilder.new()
		.name("山林體力")
		.description("高原生機盎然的體質與靈性一同灌注全軍,雙修者的治癒效果遠超一般治療技")
		.rank(GameEnums.RankType.A)
		.skill_range(0).area_shape(GameEnums.AreaShape.ALL_ALLIES).area_size(1)
		.effect_stat(GameEnums.PotentialType.VITALITY)
		.skill_type(GameEnums.SkillType.HEAL)
		.bind_weapon(GameEnums.NO_WEAPON_BINDING)
		.requires_bloodline(GameEnums.BloodlineNation.DEER)
		.base_chance(28.0).skill_ratio(1.6).secondary_stat(GameEnums.PotentialType.MENTALITY, 1.6)
		.action(Callable(SkillEffectLibrary, "heal"))
		.build())

	return skills
