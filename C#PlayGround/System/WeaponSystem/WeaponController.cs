using UtilSystem;
using SkillSystem;

namespace WeaponSystem {
    public class WeaponController {
        public static Weapon getRandomWeapon(){
            string name = getRandomName();
            Potential potential = getRandomPotential();
            WeaponType weaponType = getRandomWeaponType();
            List<Skill>? skill = getRandomSkill(weaponType);
            Weapon newWeapon = new Weapon(name,potential,weaponType,skill);
            return newWeapon;
        }

        private static string getRandomName(){
            string name = "RandomWeapon";
            return name;
        }
        private static List<Skill>? getRandomSkill(WeaponType weaponType){
            List<Skill>? skill = SkillController.getSkill(weaponType);
            if(skill != null){
                var randomSkill = skill[Util.getRandom(0,skill.Count)] ;
                randomSkill.state = true ;
                return new List<Skill>(){randomSkill} ;
            }else{
                return null;
            }
        }
        private static WeaponType getRandomWeaponType(){
                // return Util.getRandomFromEnum<WeaponType>() ;
                return WeaponType.bow ;
        }
        private static Potential getRandomPotential(){
            var potentialList = (
                strength: Util.getRandom(0,50),
                vitality: Util.getRandom(0,50),
                agility: Util.getRandom(0,50),
                dexterity: Util.getRandom(0,50),
                intelligence: Util.getRandom(0,50),
                mentality: Util.getRandom(0,50),
                strRatio: Util.getRandom(0,50),
                vitRatio: Util.getRandom(0,50),
                dexRatio: Util.getRandom(0,50),
                agiRatio: Util.getRandom(0,50),
                intRatio: Util.getRandom(0,50),
                menRatio: Util.getRandom(0,50)
            ) ;
            Potential potential = new Potential(potentialList);
            return potential;
        }
    }
}