using System;
using System.Collections;
using System.Collections.Generic;
using UtilSystem;
using SkillSystem;
using PotentialSystem;

namespace WeaponSystem {
    public class Weapon {
        //id
        private Guid id ;
        //名稱
        public string name ;
        //類型
        public WeaponType weaponType ;
        //素質
        public Potential potential ;
        //裝備狀態
        public bool equipState ;
        //等級
        public LevelSystem levelSystem;
        //武器技能
        public List<Skill> skill;
        public Weapon(
            string name,
            Potential potential,
            WeaponType weaponType,
            List<Skill> skill,
            LevelSystem levelSystem
        ){
            this.id = Guid.NewGuid();
            this.name = name;
            this.potential = potential;
            this.weaponType = weaponType;
            this.equipState = false;
            this.skill = skill;
            this.levelSystem = levelSystem;
        }
        //武器裝備狀態切換
        public void changeEquipState(bool value){
            this.equipState = value;
        }
        //取得素質方法
        private double getRealPotential(
            double initialPotential,
            double ratio
        ){
            double total = initialPotential ;
            total += ratio * levelSystem.potentialLevelConstant ;
            return total ;
        }
        //計算後力量
        public double strength {
            get {
                return getRealPotential(potential.strength,potential.strRatio);
            }
        }
        //計算後敏捷
        public double agility {
            get {
                return getRealPotential(potential.agility,potential.agiRatio);
            }
        }
        //計算後靈巧
        public double dexterity {
            get {
                return getRealPotential(potential.dexterity,potential.dexRatio);
            }
        }
        //計算後體質
        public double vitality {
            get {
                return getRealPotential(potential.vitality,potential.vitRatio);
            }
        }
        //計算後智慧
        public double intelligence {
            get {
                return getRealPotential(potential.intelligence,potential.intRatio);
            }
        }
        //計算後精神
        public double mentality {
            get {
                return getRealPotential(potential.mentality,potential.menRatio);
            }
        }
    }
}