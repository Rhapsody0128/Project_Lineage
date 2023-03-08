using UtilSystem;

namespace CharacterSystem {
    public class CharacterController {
        
        public static Character getRandomCharacter(){
            string name = getRandomName();
            Potential potential = getRandomPotential();
            Character newCharacter = new Character(name,potential);
            return newCharacter;
        }
        public static void getMarriage(Character self,Character target){
            bornChild(self,target);
        }
        public static Character bornChild(Character self,Character target){
            var potentialList = (
                Strength:102,
                Vitality:102,
                Agility:102,
                Dexterity:31,
                Intelligence:5,
                Mentality:6,
                StrRatio:1.12,
                VitRatio:2.1,
                DexRatio:1.05,
                AgiRatio:0.7,
                IntRatio:0.5,
                MenRatio:0.6
            ) ;
            Potential potential = new Potential(potentialList);
            Character child = new Character("newChild",potential);
            return child;
        }


        private static string getRandomName(){
            Random random = new Random();
            string name = "RandomPerson";
            return name;
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