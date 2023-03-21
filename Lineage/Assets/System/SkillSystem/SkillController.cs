using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UtilSystem ;
#nullable enable

namespace SkillSystem {
    public class SkillController {
        public static List<Skill> skillList = new List<Skill>(){
            new Skill("火球術",RankType.E,3,2,PotentialType.intelligence,true, WeaponType.staff),
            new Skill("百步穿揚",RankType.E,3,1,PotentialType.dexterity,true, WeaponType.bow),
            new Skill("治癒術",RankType.E,2,3,PotentialType.mentality,false, null),
            new Skill("奮力一擊",RankType.E,2,1,PotentialType.strength,false, WeaponType.sword),
        };

        public static List<Skill> getSkill(){
            return skillList;
        }
        public static Skill getSkill (int skillIndex){
            return skillList[skillIndex];
        }
        public static List<Skill>? getSkill (WeaponType weaponType){
            var result = skillList.FindAll((skill)=>{
                return (skill.BindWeapon == weaponType) ;
            })  ;
            return result ;
        }
        public static List<Skill>? getSkill (RankType skillRank){
            var result = skillList.FindAll((skill)=>{
                return (skill.skillRank == skillRank) ;
            })  ;
            return result ;
        }
    }
}