class_name SkillLibraryLeader
extends RefCounted

## 大將技,只有隊長(BattleCharacter.is_leader)能用(SkillBuilder.leader_skill()),一樣要
## 占用技能格子、消耗行動骰選,不是獨立格。前 9 支(F~SSS)是全隊增益/支援,後 9 支是
## 對全體敵人的減益(無傷害),見網站「大將技」設計:增益放大將/血統技能,武器主動技
## 儘量不做增益類。全部以自身為施法中心(ALL_ALLIES/ALL_ENEMIES 無視距離),不需要
## 移動/鎖定,見 BattleAi._cast_skill() 的 self_centered 判斷。
##
## 「攏絡」(魅惑倒戈)尚未實作戰場狀態轉換本身(只有抵抗判定,見
## CombatResolver.judge_status_resist()),亂軍之聲原本設計是攏絡,這裡先用恐懼代替,
## 等攏絡的實際效果做出來後再換掉(見 Spec.md 已知待辦)。
## 「破陣先鋒」(全隊一回合內無視防禦)、「常勝威名」(全隊一回合內必定暴擊,取代原本設計的
## 「必中」——必中對武器角色早已是常態,改成必定暴擊才夠格當 S 階獨占效果)靠
## GameEnums.SkillMechanic.GRANT_ARMOR_PIERCE/GRANT_GUARANTEED_CRIT 實作:duration_rounds
## 回合內持有者的攻擊一律視為破防/必定暴擊,不是機率觸發,1 回合的時限天然對應「每個角色
## 一回合只行動一次」,不需要另外做「用掉一次就消失」的一次性判定覆寫機制。

static func build() -> Array[Skill]:
	var skills: Array[Skill] = []
	skills.append_array(_support_skills())
	skills.append_array(_debuff_skills())
	return skills


static func _support_skills() -> Array[Skill]:
	var skills: Array[Skill] = []

	skills.append(SkillBuilder.new()
		.name("新秀統率")
		.description("初出茅廬的統率力,略微振奮全軍攻勢")
		.rank(GameEnums.RankType.F)
		.skill_range(0).area_shape(GameEnums.AreaShape.ALL_ALLIES).area_size(1)
		.effect_stat(GameEnums.PotentialType.STRENGTH)
		.skill_type(GameEnums.SkillType.BUFF)
		.bind_weapon(GameEnums.NO_WEAPON_BINDING)
		.leader_skill().base_chance(26.0).skill_ratio(0.08).duration_rounds(3)
		.buffed_stats([GameEnums.PotentialType.STRENGTH, GameEnums.PotentialType.AGILITY])
		.action(Callable(SkillEffectLibrary, "stat_buff"))
		.build())

	skills.append(SkillBuilder.new()
		.name("統帥威儀") # 既有(原「大將之風」)
		.description("隊長沉穩的威儀安定軍心,全隊體質與精神同時提升")
		.rank(GameEnums.RankType.E)
		.skill_range(0).area_shape(GameEnums.AreaShape.ALL_ALLIES).area_size(1)
		.effect_stat(GameEnums.PotentialType.VITALITY)
		.skill_type(GameEnums.SkillType.BUFF)
		.bind_weapon(GameEnums.NO_WEAPON_BINDING)
		.leader_skill().base_chance(25.0).skill_ratio(0.10).duration_rounds(3)
		.buffed_stats([GameEnums.PotentialType.VITALITY, GameEnums.PotentialType.MENTALITY])
		.action(Callable(SkillEffectLibrary, "stat_buff"))
		.build())

	skills.append(SkillBuilder.new()
		.name("沉著號令") # 「敏捷提升」簡化為 AGI 加成,見通用被動同樣的簡化
		.description("冷靜精準的號令聲響徹戰場,全隊敏捷提升")
		.rank(GameEnums.RankType.D)
		.skill_range(0).area_shape(GameEnums.AreaShape.ALL_ALLIES).area_size(1)
		.effect_stat(GameEnums.PotentialType.AGILITY)
		.skill_type(GameEnums.SkillType.BUFF)
		.bind_weapon(GameEnums.NO_WEAPON_BINDING)
		.leader_skill().base_chance(28.0).skill_ratio(0.08).duration_rounds(3)
		.buffed_stats([GameEnums.PotentialType.AGILITY])
		.action(Callable(SkillEffectLibrary, "stat_buff"))
		.build())

	skills.append(SkillBuilder.new()
		.name("破陣先鋒")
		.description("身先士卒衝鋒陷陣,自身力量提升,並讓全隊一回合內無視防禦")
		.rank(GameEnums.RankType.C)
		.skill_range(0).area_shape(GameEnums.AreaShape.ALL_ALLIES).area_size(1)
		.effect_stat(GameEnums.PotentialType.STRENGTH)
		.skill_type(GameEnums.SkillType.BUFF)
		.bind_weapon(GameEnums.NO_WEAPON_BINDING)
		.leader_skill().base_chance(30.0).skill_ratio(0.10).duration_rounds(1)
		.buffed_stats([GameEnums.PotentialType.STRENGTH])
		.mechanics([GameEnums.SkillMechanic.GRANT_ARMOR_PIERCE])
		.action(Callable(SkillEffectLibrary, "stat_buff_with_mechanic"))
		.build())

	skills.append(SkillBuilder.new()
		.name("智將韜略")
		.description("運籌帷幄的智謀,本回合全隊選用主動技能的機率提升")
		.rank(GameEnums.RankType.B)
		.skill_range(0).area_shape(GameEnums.AreaShape.ALL_ALLIES).area_size(1)
		.effect_stat(GameEnums.PotentialType.INTELLIGENCE)
		.skill_type(GameEnums.SkillType.BUFF)
		.bind_weapon(GameEnums.NO_WEAPON_BINDING)
		.leader_skill().base_chance(30.0).skill_ratio(0.30).duration_rounds(2)
		.action(Callable(SkillEffectLibrary, "skill_weight_buff"))
		.build())

	skills.append(SkillBuilder.new()
		.name("鐵血統帥")
		.description("鐵一般的意志統率全軍,小量治療全隊並提升體質")
		.rank(GameEnums.RankType.A)
		.skill_range(0).area_shape(GameEnums.AreaShape.ALL_ALLIES).area_size(1)
		.effect_stat(GameEnums.PotentialType.VITALITY)
		.skill_type(GameEnums.SkillType.HEAL)
		.bind_weapon(GameEnums.NO_WEAPON_BINDING)
		.leader_skill().base_chance(32.0).skill_ratio(1.0).duration_rounds(3)
		.buffed_stats([GameEnums.PotentialType.VITALITY])
		.action(Callable(SkillEffectLibrary, "heal_with_buff"))
		.build())

	skills.append(SkillBuilder.new()
		.name("常勝威名")
		.description("百戰百勝累積下的威名,使全隊一回合內必定暴擊")
		.rank(GameEnums.RankType.S)
		.skill_range(0).area_shape(GameEnums.AreaShape.ALL_ALLIES).area_size(1)
		.effect_stat(GameEnums.PotentialType.DEXTERITY)
		.skill_type(GameEnums.SkillType.BUFF)
		.bind_weapon(GameEnums.NO_WEAPON_BINDING)
		.leader_skill().base_chance(30.0).skill_ratio(0.0).duration_rounds(1)
		.mechanics([GameEnums.SkillMechanic.GRANT_GUARANTEED_CRIT])
		.action(Callable(SkillEffectLibrary, "mechanic_buff"))
		.build())

	skills.append(SkillBuilder.new()
		.name("王者號令")
		.description("不容置疑的號令,提升全隊力量、敏捷、靈巧")
		.rank(GameEnums.RankType.SS)
		.skill_range(0).area_shape(GameEnums.AreaShape.ALL_ALLIES).area_size(1)
		.effect_stat(GameEnums.PotentialType.STRENGTH)
		.skill_type(GameEnums.SkillType.BUFF)
		.bind_weapon(GameEnums.NO_WEAPON_BINDING)
		.leader_skill().base_chance(32.0).skill_ratio(0.10).duration_rounds(1)
		.buffed_stats([GameEnums.PotentialType.STRENGTH, GameEnums.PotentialType.AGILITY, GameEnums.PotentialType.DEXTERITY])
		.action(Callable(SkillEffectLibrary, "stat_buff"))
		.build())

	skills.append(SkillBuilder.new()
		.name("傳世霸業")
		.description("載入史冊的統率霸業,一瞬間讓全軍六大素質同時攀上巔峰,但這股亢奮難以持久")
		.rank(GameEnums.RankType.SSS)
		.skill_range(0).area_shape(GameEnums.AreaShape.ALL_ALLIES).area_size(1)
		.effect_stat(GameEnums.PotentialType.STRENGTH)
		.skill_type(GameEnums.SkillType.BUFF)
		.bind_weapon(GameEnums.NO_WEAPON_BINDING)
		.leader_skill().base_chance(34.0).skill_ratio(0.06).duration_rounds(1)
		.buffed_stats([
			GameEnums.PotentialType.STRENGTH, GameEnums.PotentialType.VITALITY,
			GameEnums.PotentialType.AGILITY, GameEnums.PotentialType.DEXTERITY,
			GameEnums.PotentialType.INTELLIGENCE, GameEnums.PotentialType.MENTALITY,
		])
		.action(Callable(SkillEffectLibrary, "stat_buff"))
		.build())

	return skills


static func _debuff_skills() -> Array[Skill]:
	var skills: Array[Skill] = []

	skills.append(SkillBuilder.new()
		.name("亂陣輕擾")
		.description("號令一出擾亂敵陣步調,全體敵人敏捷小幅下降")
		.rank(GameEnums.RankType.F)
		.skill_range(0).area_shape(GameEnums.AreaShape.ALL_ENEMIES).area_size(1)
		.effect_stat(GameEnums.PotentialType.AGILITY)
		.skill_type(GameEnums.SkillType.DEBUFF)
		.bind_weapon(GameEnums.NO_WEAPON_BINDING)
		.leader_skill().base_chance(26.0).skill_ratio(-0.08).duration_rounds(2)
		.buffed_stats([GameEnums.PotentialType.AGILITY])
		.action(Callable(SkillEffectLibrary, "stat_debuff"))
		.build())

	skills.append(SkillBuilder.new()
		.name("怯戰低語")
		.description("低沉的號令聲傳遍敵陣,動搖敵人的戰意")
		.rank(GameEnums.RankType.E)
		.skill_range(0).area_shape(GameEnums.AreaShape.ALL_ENEMIES).area_size(1)
		.effect_stat(GameEnums.PotentialType.MENTALITY)
		.skill_type(GameEnums.SkillType.DEBUFF)
		.bind_weapon(GameEnums.NO_WEAPON_BINDING)
		.leader_skill().base_chance(25.0).skill_ratio(0.0).duration_rounds(1)
		.mechanics([GameEnums.SkillMechanic.FEAR])
		.action(Callable(SkillEffectLibrary, "mechanic_debuff"))
		.build())

	skills.append(SkillBuilder.new()
		.name("封喉號令")
		.description("一聲令下鎖住敵人的招式,使其只能倉促應戰")
		.rank(GameEnums.RankType.D)
		.skill_range(0).area_shape(GameEnums.AreaShape.ALL_ENEMIES).area_size(1)
		.effect_stat(GameEnums.PotentialType.MENTALITY)
		.skill_type(GameEnums.SkillType.DEBUFF)
		.bind_weapon(GameEnums.NO_WEAPON_BINDING)
		.leader_skill().base_chance(24.0).skill_ratio(0.0).duration_rounds(1)
		.mechanics([GameEnums.SkillMechanic.SEAL])
		.action(Callable(SkillEffectLibrary, "mechanic_debuff"))
		.build())

	skills.append(SkillBuilder.new()
		.name("亂軍之聲") # 原設計為攏絡,暫以恐懼代替,見檔頭註解
		.description("刻意散布的錯亂號令,擾亂敵人本回合的判斷")
		.rank(GameEnums.RankType.C)
		.skill_range(0).area_shape(GameEnums.AreaShape.ALL_ENEMIES).area_size(1)
		.effect_stat(GameEnums.PotentialType.MENTALITY)
		.skill_type(GameEnums.SkillType.DEBUFF)
		.bind_weapon(GameEnums.NO_WEAPON_BINDING)
		.leader_skill().base_chance(22.0).skill_ratio(0.0).duration_rounds(1)
		.mechanics([GameEnums.SkillMechanic.FEAR])
		.action(Callable(SkillEffectLibrary, "mechanic_debuff"))
		.build())

	skills.append(SkillBuilder.new()
		.name("摧志怒吼")
		.description("一聲怒吼擊碎敵人的鬥志,全體敵人力量下降")
		.rank(GameEnums.RankType.B)
		.skill_range(0).area_shape(GameEnums.AreaShape.ALL_ENEMIES).area_size(1)
		.effect_stat(GameEnums.PotentialType.STRENGTH)
		.skill_type(GameEnums.SkillType.DEBUFF)
		.bind_weapon(GameEnums.NO_WEAPON_BINDING)
		.leader_skill().base_chance(26.0).skill_ratio(-0.10).duration_rounds(2)
		.buffed_stats([GameEnums.PotentialType.STRENGTH])
		.action(Callable(SkillEffectLibrary, "stat_debuff"))
		.build())

	skills.append(SkillBuilder.new()
		.name("絕境圍剿")
		.description("號令全軍趁勝追擊,使敵人的傷口難以被治癒")
		.rank(GameEnums.RankType.A)
		.skill_range(0).area_shape(GameEnums.AreaShape.ALL_ENEMIES).area_size(1)
		.effect_stat(GameEnums.PotentialType.MENTALITY)
		.skill_type(GameEnums.SkillType.DEBUFF)
		.bind_weapon(GameEnums.NO_WEAPON_BINDING)
		.leader_skill().base_chance(24.0).skill_ratio(0.0).duration_rounds(2)
		.mechanics([GameEnums.SkillMechanic.HEAL_DOWN])
		.action(Callable(SkillEffectLibrary, "mechanic_debuff"))
		.build())

	skills.append(SkillBuilder.new()
		.name("破陣長嘯")
		.description("聲勢驚人的長嘯震碎敵人防線,全體敵人體質下降")
		.rank(GameEnums.RankType.S)
		.skill_range(0).area_shape(GameEnums.AreaShape.ALL_ENEMIES).area_size(1)
		.effect_stat(GameEnums.PotentialType.VITALITY)
		.skill_type(GameEnums.SkillType.DEBUFF)
		.bind_weapon(GameEnums.NO_WEAPON_BINDING)
		.leader_skill().base_chance(26.0).skill_ratio(-0.12).duration_rounds(2)
		.buffed_stats([GameEnums.PotentialType.VITALITY])
		.action(Callable(SkillEffectLibrary, "stat_debuff"))
		.build())

	skills.append(SkillBuilder.new()
		.name("軍心渙散")
		.description("號令徹底擊潰敵人心理防線,恐懼之餘傷口也難以癒合")
		.rank(GameEnums.RankType.SS)
		.skill_range(0).area_shape(GameEnums.AreaShape.ALL_ENEMIES).area_size(1)
		.effect_stat(GameEnums.PotentialType.MENTALITY)
		.skill_type(GameEnums.SkillType.DEBUFF)
		.bind_weapon(GameEnums.NO_WEAPON_BINDING)
		.leader_skill().base_chance(24.0).skill_ratio(0.0).duration_rounds(1)
		.mechanics([GameEnums.SkillMechanic.FEAR, GameEnums.SkillMechanic.HEAL_DOWN])
		.action(Callable(SkillEffectLibrary, "mechanic_debuff"))
		.build())

	skills.append(SkillBuilder.new()
		.name("天譴降臨")
		.description("載入史冊的滅軍號令,全體敵體質重挫並遭到封印")
		.rank(GameEnums.RankType.SSS)
		.skill_range(0).area_shape(GameEnums.AreaShape.ALL_ENEMIES).area_size(1)
		.effect_stat(GameEnums.PotentialType.VITALITY)
		.skill_type(GameEnums.SkillType.DEBUFF)
		.bind_weapon(GameEnums.NO_WEAPON_BINDING)
		.leader_skill().base_chance(28.0).skill_ratio(-0.15).duration_rounds(1)
		.buffed_stats([GameEnums.PotentialType.VITALITY])
		.mechanics([GameEnums.SkillMechanic.SEAL])
		.action(Callable(SkillEffectLibrary, "stat_debuff_with_mechanic"))
		.build())

	return skills
