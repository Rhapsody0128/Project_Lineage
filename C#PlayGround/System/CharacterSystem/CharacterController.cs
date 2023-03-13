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
                strength:102,
                vitality:102,
                agility:102,
                dexterity:31,
                intelligence:5,
                mentality:6,
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