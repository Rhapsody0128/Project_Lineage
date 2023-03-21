using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UtilSystem ;

namespace SkillSystem {
    public class Skill {
        public string name ;
        public RankType skillRank ;
        public int range ;
        public int scope ;
        public PotentialType effectBasedOn ;
        public bool effectTargetEnemy ;
        public WeaponType? BindWeapon  ; 
        public bool state = false; 
        
        public Skill(
            string name,
            RankType skillRank,
            int range,
            int scope,
            PotentialType effectBasedOn,
            bool effectTargetEnemy,
            WeaponType? BindWeapon
        ){
            this.name = name;
            this.skillRank = skillRank;
            this.range = range;
            this.scope = scope;
            this.effectBasedOn = effectBasedOn;
            this.effectTargetEnemy = effectTargetEnemy;
            this.BindWeapon = BindWeapon;
        }
    }
}