using UtilSystem;
using SkillSystem;

namespace CharacterSystem {
    public class CharacterController {
        
        public static Character getRandomCharacter(){
            string name = Util.getRandomFromEnum<MaleCharacterName>().ToString();
            string lastName = Util.getRandomFromEnum<MaleCharacterLastName>().ToString();
            Potential potential = getRandomPotential();
            List<Skill>? skill = getRandomSkill(RankType.E) ;
            Character newCharacter = new Character(name,lastName,potential,skill);
            return newCharacter;
        }
        public static void getMarriage(Character self,Character target){
            bornChild(self,target);
        }
        private static List<Skill>? getRandomSkill(RankType rankType){
            List<Skill>? skill = SkillController.getSkill(rankType);
            if(skill != null){
                var randomSkill = skill[Util.getRandom(0,skill.Count)] ;
                randomSkill.state = true ;
                return new List<Skill>(){randomSkill} ;
            }else{
                return null;
            }
        }
        public static Character bornChild(Character self,Character target){
            var potentialList = (
                strength:102,
                vitality:102,
                agility:102,
                dexterity:31,
                intelligence:5,
                mentality:6,
                strRatio:1.12,
                vitRatio:2.1,
                dexRatio:1.05,
                agiRatio:0.7,
                intRatio:0.5,
                menRatio:0.6
            ) ;
            Potential potential = new Potential(potentialList);
            Character child = new Character("newChild","lastName",potential,null);
            return child;
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