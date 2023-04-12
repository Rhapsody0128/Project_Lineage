using System;
using System.Collections;
using System.Collections.Generic;
using UtilSystem ;
using PotentialSystem;

namespace SkillSystem {
    public class SkillController {
        //全技能庫
        private static List<Skill> skillLibrary = new List<Skill>(){
            new Skill("火球術",RankType.E,3,2,PotentialType.intelligence,SkillEffectType.attack, WeaponType.staff),
            new Skill("百步穿揚",RankType.E,3,1,PotentialType.dexterity,SkillEffectType.attack, WeaponType.bow),
            new Skill("治癒術",RankType.E,3,1,PotentialType.mentality,SkillEffectType.heal, null),
            new Skill("奮力一擊",RankType.E,2,1,PotentialType.strength,SkillEffectType.attack, WeaponType.sword),
            new Skill("加速",RankType.E,1,1,PotentialType.mentality,SkillEffectType.buff,WeaponType.dagger),
            new Skill("挑釁",RankType.E,3,3,PotentialType.vitality,SkillEffectType.debuff,WeaponType.shield),
            new Skill("守護",RankType.E,5,1,PotentialType.vitality,SkillEffectType.defend,WeaponType.dagger)
        };
        //取得技能庫
        public static List<Skill> getSkillLibrary(){
            return skillLibrary;
        }
        //取得技能byIndex
        public static Skill getSkill (int skillIndex){
            return skillLibrary[skillIndex];
        }
        //取得某武器的技能庫
        public static List<Skill> getSkillLibrary (WeaponType weaponType){
            var result = skillLibrary.FindAll((skill)=>{
                return (skill.BindWeapon == weaponType) ;
            })  ;
            return result ;
        }
        //取得某Rank的技能庫
        public static List<Skill> getSkillLibrary (RankType skillRank){
            var result = skillLibrary.FindAll((skill)=>{
                return (skill.skillRank == skillRank) ;
            })  ;
            return result ;
        }
        //取得隨機技能庫
        public static List<Skill> getRandomSkillLibrary (){
            List<Skill> skill = SkillController.getSkillLibrary();
            if (skill != null)
            {
                var randomSkill = skill[Util.getRandom(0, skill.Count)];
                return new List<Skill>(){ randomSkill } ;
            }
            else {
                return new() { };
            }
        }
        //取得某武器的隨機技能庫
        public static List<Skill> getRandomSkillLibrary (WeaponType weaponType){
            List<Skill> skill = SkillController.getSkillLibrary(weaponType);
            if(skill != null){
                var randomSkill = skill[Util.getRandom(0,skill.Count)] ;
                return new (){randomSkill} ;
            }else{
                return new() { };
            }
        }
        //取得Rank的隨機技能庫
        public static List<Skill> getRandomSkill(RankType rankType){
            List<Skill> skill = SkillController.getSkillLibrary(rankType);
            if(skill != null){
                var randomSkill = skill[Util.getRandom(0,skill.Count)] ;
                return new (){randomSkill} ;
            }else{
                return new() { };
            }
        }
    }
}