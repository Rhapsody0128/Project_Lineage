using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UtilSystem;
using SkillSystem;
#nullable enable

namespace RoleSystem {
    public class  RoleController {
        
        public static Role getRandomRole(){
            string name = Util.getRandomFromEnum<MaleRoleName>().ToString();
            string lastName = Util.getRandomFromEnum<MaleRoleLastName>().ToString();
            Potential potential = getRandomPotential();
            List<Skill>? skill = getRandomSkill(RankType.E) ;
            Role newRole = new Role(name,lastName,potential,skill);
            return newRole;
        }
        public static void getMarriage(Role self,Role target){
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
        private static Potential getRandomPotential(){
            var potentialList = (
                strength: Util.getRandom(0,50),
                vitality: Util.getRandom(0,50),
                agility: Util.getRandom(0,50),
                dexterity: Util.getRandom(0,50),
                intelligence: Util.getRandom(0,50),
                mentality: Util.getRandom(0,50),
                strRatio: Util.getRandom(0.5,2),
                vitRatio: Util.getRandom(0.5,2),
                dexRatio: Util.getRandom(0.5,2),
                agiRatio: Util.getRandom(0.5,2),
                intRatio: Util.getRandom(0.5,2),
                menRatio: Util.getRandom(0.5,2)
            ) ;
            Potential potential = new Potential(potentialList);
            return potential;
        }
    }
}