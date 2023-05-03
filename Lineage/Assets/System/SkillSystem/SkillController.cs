using System;
using System.Collections;
using System.Collections.Generic;
using UtilSystem ;
using PotentialSystem;
using BattleSystem;
using PartySystem;

namespace SkillSystem {
    public class SkillController {
        //全技能庫
        private static List<Skill> skillLibrary = new List<Skill>(){
            new Skill(
                "火球術",
                "用法杖施放火球術",
                RankType.E,
                3,
                2,
                PotentialType.intelligence,
                SkillEffectType.attack,
                WeaponType.staff,
                50,
                (BattleParty selfParty,BattleParty enemyParty,Skill skill)=>{
                    Console.WriteLine(selfParty.name + skill.description + enemyParty.name);
                }
            ),
            //new Skill("百步穿揚",RankType.E,3,1,PotentialType.dexterity,SkillEffectType.attack, WeaponType.bow),
            //new Skill("治癒術",RankType.E,3,1,PotentialType.mentality,SkillEffectType.heal, null),
            //new Skill("奮力一擊",RankType.E,2,1,PotentialType.strength,SkillEffectType.attack, WeaponType.sword),
            //new Skill("加速",RankType.E,1,1,PotentialType.mentality,SkillEffectType.buff,WeaponType.dagger),
            //new Skill("挑釁",RankType.E,3,3,PotentialType.vitality,SkillEffectType.debuff,WeaponType.shield),
            //new Skill("守護",RankType.E,5,1,PotentialType.vitality,SkillEffectType.defend,WeaponType.dagger)
        };
        //取得技能庫
        public static List<Skill> getSkillList(){
            return skillLibrary;
        }
        //取得技能byIndex
        public static Skill getSkill (int skillIndex){
            return skillLibrary[skillIndex];
        }
        //取得某武器的技能庫(含通用)
        public static List<Skill> getSkillList (WeaponType weaponType){
            var result = skillLibrary.FindAll((skill)=>{
                return (skill.BindWeapon == weaponType || weaponType == WeaponType.empty) ;
            }) ;
            return result ;
        }
        //取得某Rank的技能庫
        public static List<Skill> getSkillList (RankType skillRank){
            var result = skillLibrary.FindAll((skill)=>{
                return (skill.skillRank == skillRank) ;
            })  ;
            return result ;
        }
        //取得隨機技能庫
        public static List<Skill> getRandomSkillList (){
            List<Skill> skillList = SkillController.getSkillList();
            if (skillList.Count != 0)
            {
                var randomSkill = skillList[Util.getRandom(0, skillList.Count - 1)];
                return new List<Skill>(){ randomSkill } ;
            }
            else {
                return new() { };
            }
        }
        //取得某武器的隨機技能庫
        public static List<Skill> getRandomSkillList (WeaponType weaponType){
            List<Skill> skillList = SkillController.getSkillList(weaponType);
            if(skillList.Count != 0)
            {
                var randomSkill = skillList[Util.getRandom(0, skillList.Count -1 )] ;
                return new (){randomSkill} ;
            }else{
                return new() { };
            }
        }
        //取得Rank的隨機技能庫
        public static List<Skill> getRandomSkillList(RankType rankType){
            List<Skill> skillList = SkillController.getSkillList(rankType);
            if(skillList.Count != 0)
            {
                var randomSkill = skillList[Util.getRandom(0, skillList.Count - 1)] ;
                return new (){randomSkill} ;
            }else{
                return new() { };
            }
        }
    }
}