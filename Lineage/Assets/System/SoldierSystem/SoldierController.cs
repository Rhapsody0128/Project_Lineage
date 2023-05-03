using System;
using System.Collections;
using System.Collections.Generic;
using UtilSystem;
using PotentialSystem;
using HeroSystem;
using SkillSystem;

namespace SoldierSystem {
    public class SoldierController{
        //隨機兵團
        static public Soldier getRandomSoldier(){
            var hero = HeroController.getRandomHero() ;
            var potential = PotentialController.getRandomPotential() ;
            var skill = SkillController.getRandomSkillList() ;
            var soldier = new Soldier("隨機的部隊",potential,skill,new LevelSystem()) ;
            return soldier ;
        }
    }
}