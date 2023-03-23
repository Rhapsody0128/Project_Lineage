using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UtilSystem;
using PotentialSystem;
using SkillSystem;

namespace TroopSystem {
    public class Troop {
      public string name ;
      public int soldiersCount ;
      public Potential potential ;
      public List<Skill>? skill = new List<Skill>();
      public LevelSystem? levelSystem = new LevelSystem() ;

      public Troop(            
        string name,
        Potential potential,
        List<Skill>? skill,
        LevelSystem? levelSystem = null
      ){
        this.name = name ;
        this.soldiersCount = 200 ;  
        this.potential = potential ;
        this.skill = skill ;
        this.levelSystem = levelSystem ?? new LevelSystem();
      }


      private double getRealPotential(
            double initialPotential,
            double ratio
        ){
            double total = initialPotential ;
            total += ratio * levelSystem.level * 5 ;
            return total ;
        }
        public double strength {
            get {
                return getRealPotential(potential.strength,potential.strRatio);
            }
        }
        public double agility {
            get {
                return getRealPotential(potential.agility,potential.agiRatio);
            }
        }
        public double dexterity {
            get {
                return getRealPotential(potential.dexterity,potential.dexRatio);
            }
        }
        public double vitality {
            get {
                return getRealPotential(potential.vitality,potential.vitRatio);
            }
        }
        public double intelligence {
            get {
                return getRealPotential(potential.intelligence,potential.intRatio);
            }
        }
        public double mentality {
            get {
                return getRealPotential(potential.mentality,potential.menRatio);
            }
        }

    }
}