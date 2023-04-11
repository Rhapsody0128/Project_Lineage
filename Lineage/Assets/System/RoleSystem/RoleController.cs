using System;
using System.Collections;
using System.Collections.Generic;
using UtilSystem;
using PotentialSystem;
using SkillSystem;

namespace RoleSystem {
    public class  RoleController {
        
        public static Role getRandomRole(){
            var name = Util.getRandomFromEnum<MaleRoleName>().ToString();
            var lastName = Util.getRandomFromEnum<MaleRoleLastName>().ToString();
            var potential = PotentialController.getRandomPotential();
            var skill = SkillController.getRandomSkill(RankType.E) ;
            var newRole = new Role(name,lastName,potential,skill);
            return newRole;
        }
        public static void getMarriage(Role self,Role target){
            bornChild(self,target);
        }
        public static Role bornChild(Role self,Role target){
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
            Role child = new Role("newChild","lastName",potential,null);
            return child;
        }
        
    }
}