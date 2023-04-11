using System;
using System.Collections;
using System.Collections.Generic;
using UtilSystem;
using SkillSystem;
using PotentialSystem;
#nullable enable

namespace WeaponSystem {
    public class Weapon {
        private Guid id ;
        public string name ;
        public WeaponType weaponType ;
        public Potential potential ;
        public bool equipState ;

        public LevelSystem levelSystem;
        
        public List<Skill>? skill = new List<Skill>();
        public Weapon(
            string name,
            Potential potential,
            WeaponType weaponType,
            List<Skill>? skill,
            LevelSystem? levelSystem = null
        ){
            this.id = Guid.NewGuid();
            this.name = name;
            this.potential = potential;
            this.weaponType = weaponType;
            this.equipState = false;
            this.skill = skill;
            this.levelSystem = levelSystem ?? new LevelSystem();
        }
        public void changeEquipState(bool value){
            this.equipState = value;
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