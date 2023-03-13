using UtilSystem ;

namespace SkillSystem {
    public class SkillController {
        public static List<Skill> skillList = new List<Skill>(){
            new Skill("火球術",3,2,PotentialType.intelligence,true, WeaponType.staff),
            new Skill("百步穿揚",3,1,PotentialType.dexterity,true, WeaponType.bow),
            new Skill("治癒術",2,3,PotentialType.mentality,false, null),
            new Skill("奮力一擊",2,1,PotentialType.strength,false, WeaponType.sword),
        };

        public static List<Skill> getSkill(){
            return skillList;
        }
        public static Skill getSkill (int skillIndex){
            return skillList[skillIndex];
        }
        public static List<Skill>? getSkill (WeaponType WeaponType){
            var result = skillList.Where((skill)=>{
                return (skill.BindWeapon == WeaponType) ;
            })  ;
            return result.ToList() ;
        }
    }
}