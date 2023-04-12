using System;
using System.Collections;
using System.Collections.Generic;
using UtilSystem ;
using PotentialSystem;

namespace SkillSystem {
    public class Skill {
        //技能名
        public string name ;
        //技能評比
        public RankType skillRank ;
        //施放距離
        public int range ;
        //施放範圍
        public int scope ;
        //素質基礎
        public PotentialType effectBasedOn ;
        //技能類型
        public SkillEffectType skillEffectType;
        //綁定武器
        public WeaponType? BindWeapon  ;
        
        public Skill(
            string name,
            RankType skillRank,
            int range,
            int scope,
            PotentialType effectBasedOn,
            SkillEffectType skillEffectType,
            WeaponType? BindWeapon
        ){
            this.name = name;
            this.skillRank = skillRank;
            this.range = range;
            this.scope = scope;
            this.effectBasedOn = effectBasedOn;
            this.skillEffectType = skillEffectType;
            this.BindWeapon = BindWeapon;
        }
    }
}