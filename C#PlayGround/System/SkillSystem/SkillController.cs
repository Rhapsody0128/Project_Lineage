using System.Collections.Generic;
using UtilSystem ;

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
            var result = skillList.Where((skill)=>{
                return (skill.BindWeapon == weaponType) ;
            })  ;
            return result.ToList() ;
        }
        public static List<Skill>? getSkill (RankType skillRank){
            var result = skillList.Where((skill)=>{
                return (skill.skillRank == skillRank) ;
            })  ;
            return result.ToList() ;
        }
    }
}