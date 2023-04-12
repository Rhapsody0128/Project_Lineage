using System;
using System.Collections;
using System.Collections.Generic;
using UtilSystem;
using PotentialSystem;
using RoleSystem;
using SkillSystem;

namespace TroopSystem {
    public class TroopController{
        //隨機兵團
        static public Troop getRandomTroop(){
            var leader = RoleController.getRandomRole() ;
            var potential = PotentialController.getRandomPotential() ;
            var skill = SkillController.getRandomSkillLibrary() ;
            var troop = new Troop("隨機的部隊",potential,skill,new LevelSystem()) ;
            return troop ;
        }
    }
}