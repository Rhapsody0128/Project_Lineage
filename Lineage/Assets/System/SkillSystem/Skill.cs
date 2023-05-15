using System;
using System.Collections;
using System.Collections.Generic;
using UtilSystem ;
using PotentialSystem;
using BattleSystem;
using Newtonsoft.Json;

namespace SkillSystem {
    public class Skill {
        public Guid id;
        //技能名
        public string name ;
        //技能說明
        public string description;
        //技能評比
        public RankType skillRank ;
        //施放距離
        public int range ;
        //施放範圍
        public int scope ;
        //素質基礎
        public PotentialType effectBasedOn ;
        //技能類型
        public SkillType skillType;
        //綁定武器
        public WeaponType BindWeapon ;
        //基礎觸發機率
        public double baseChance;
        //隊長技
        public bool isLeaderSkill;


        [JsonIgnore]
        public Action<BattleParty, BattleParty,Skill> action;

        public Skill(
            string name,
            string description,
            RankType skillRank,
            int range,
            int scope,
            PotentialType effectBasedOn,
            SkillType skillType,
            WeaponType BindWeapon,
            bool isLeaderSkill,
            double baseChance,
            Action<BattleParty,BattleParty,Skill> action
        )
        {
            this.id = Guid.NewGuid();
            this.name = name;
            this.description = description;
            this.skillRank = skillRank;
            this.range = range;
            this.scope = scope;
            this.effectBasedOn = effectBasedOn;
            this.skillType = skillType;
            this.BindWeapon = BindWeapon;
            this.isLeaderSkill = isLeaderSkill;
            this.baseChance = baseChance;
            this.action = action;
            
        }
        public void effect(BattleParty selfParty, BattleParty targetParty) {
            action(selfParty, targetParty,this);
        }
    }
}