using UtilSystem;

namespace WeaponSystem {
    public class WeaponController {
        public static Weapon getRandomWeapon(){
            string name = getRandomName();
            Ability ability = getRandomAbility();
            WeaponAttributes weaponAttributes = getWeaponAttributes();
            Weapon newWeapon = new Weapon(name,ability,weaponAttributes);
            return newWeapon;
        }

        private static string getRandomName(){
            Random random = new Random();
            string name = "RandomWeapon";
            return name;
        }
        private static WeaponAttributes getWeaponAttributes(){
            Random random = new Random();
            WeaponAttributes weaponAttributes = WeaponAttributesList.getWeaponAttributes(random.Next(0,WeaponAttributesList.getWeaponAttributesList().Count));
            return weaponAttributes;
        }
        private static Ability getRandomAbility(){
            Random random = new Random();
            Potential potential = getRandomPotential();
            Ability ability = new Ability(potential);
            return ability;
        }
        private static Potential getRandomPotential(){
            Random random = new Random();
            var potentialList = (
                Strength:random.Next(0,50),
                Vitality:random.Next(0,50),
                Agility:random.Next(0,50),
                Dexterity:random.Next(0,50),
                Intelligence:random.Next(0,50),
                Mentality:random.Next(0,50),
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