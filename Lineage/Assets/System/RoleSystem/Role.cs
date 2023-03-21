using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UtilSystem;
using WeaponSystem;
using SkillSystem;
#nullable enable

namespace RoleSystem {
    public class Role {
        private Guid id ;
        public string name ;
        public string lastName ;
        public Potential potential ;
        public Weapon? holdingWeapon ;
        public List<Skill>? skill = new List<Skill>();
        public int military ;
        public LevelSystem levelSystem ;
        
        public Role(
            string name,
            string lastName,
            Potential potential,
            List<Skill>? skill,
            LevelSystem? levelSystem = null
        ){
            this.name = name;
            this.lastName = lastName;
            this.id = Guid.NewGuid();
            this.potential = potential;
            this.skill = skill ;
            this.military = 1000 ; 
            if(levelSystem != null){
                this.levelSystem = levelSystem ;
            }else{
                this.levelSystem = new LevelSystem() ;
            }
        }       
        public void equipWeapon(Weapon weapon){

            if(weapon.equipState is true){
                return ;
                // throw new InvalidOperationException("weapon has been equiped");
            }
            if(this.holdingWeapon is not null){
                this.holdingWeapon.changeEquipState(false);
            }
            this.holdingWeapon = weapon;
            this.holdingWeapon.changeEquipState(true);

        }
        public void unEquipWeapon(){
            if(this.holdingWeapon is null){
                return ;
                // throw new InvalidOperationException("no weapon to unEquip");
            }
            this.holdingWeapon.changeEquipState(false);
            this.holdingWeapon = null;
        }

        public void gainExp(int expNumber){
            
        }
        public void upgrade(){
            
        }
        
        private double getRealPotential(
            double initialPotential,
            double ratio,
            double weaponPotential
        ){
            double total = initialPotential ;
            total += ratio * levelSystem.level * 5 ;
            total += weaponPotential ;
            return total ;
        }
        public double strength {
            get {
                double weaponPotential = 0  ;
                if(holdingWeapon != null){
                    weaponPotential = holdingWeapon.strength ;
                }
                return getRealPotential(potential.strength,potential.strRatio,weaponPotential);
            }
        }
        public double agility {
            get {
                double weaponPotential = 0  ;
                if(holdingWeapon != null){
                    weaponPotential = holdingWeapon.agility ;
                }
                return getRealPotential(potential.agility,potential.agiRatio,weaponPotential);
            }
        }
        public double dexterity {
            get {
                double weaponPotential = 0  ;
                if(holdingWeapon != null){
                    weaponPotential = holdingWeapon.dexterity ;
                }
                return getRealPotential(potential.dexterity,potential.dexRatio,weaponPotential);
            }
        }
        public double vitality {
            get {
                double weaponPotential = 0  ;
                if(holdingWeapon != null){
                    weaponPotential = holdingWeapon.vitality ;
                }
                return getRealPotential(potential.vitality,potential.vitRatio,weaponPotential);
            }
        }
        public double intelligence {
            get {
                double weaponPotential = 0  ;
                if(holdingWeapon != null){
                    weaponPotential = holdingWeapon.intelligence ;
                }
                return getRealPotential(potential.intelligence,potential.intRatio,weaponPotential);
            }
        }
        public double mentality {
            get {
                double weaponPotential = 0  ;
                if(holdingWeapon != null){
                    weaponPotential = holdingWeapon.mentality ;
                }
                return getRealPotential(potential.mentality,potential.menRatio,weaponPotential);
            }
        }
    }
}