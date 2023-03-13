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
            Random random = new Random();
            string name = "RandomWeapon";
            return name;
        }
        private static List<Skill>? getRandomSkill(WeaponType weaponType){
            Random random = new Random();
            List<Skill>? skill = SkillController.getSkill(weaponType);
            if(skill != null){
                var randomSkill = skill[random.Next(0,skill.Count)] ; 
                return new List<Skill>(){randomSkill} ;
            }else{
                return null;
            }
        }
        private static WeaponType getRandomWeaponType(){
                Random random = new Random();
                return (WeaponType) random.Next(Enum.GetNames(typeof(WeaponType)).Length);
        }
        private static Potential getRandomPotential(){
            Random random = new Random();
            var potentialList = (
                strength:random.Next(0,50),
                vitality:random.Next(0,50),
                agility:random.Next(0,50),
                dexterity:random.Next(0,50),
                intelligence:random.Next(0,50),
                mentality:random.Next(0,50),
                StrRatio:random.Next(0,2),
                VitRatio:random.Next(0,2),
                DexRatio:random.Next(0,2),
                AgiRatio:random.Next(0,2),
                IntRatio:random.Next(0,2),
                MenRatio:random.Next(0,2)
            ) ;
            Potential potential = new Potential(potentialList);
            return potential;
        }
    }
}