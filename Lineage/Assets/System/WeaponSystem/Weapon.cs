using PotentialSystem;
using SkillSystem;
using System;
using System.Collections;
using System.Collections.Generic;
using UtilSystem;

namespace WeaponSystem
{
    public class Weapon
    {
        //id
        public Guid id;
        //名稱
        public string name;
        //類型
        public WeaponType weaponType;
        //素質
        public Potential potential;
        //裝備狀態
        public bool equipState;
        //等級
        public LevelSystem levelSystem;
        //武器技能
        public List<Skill> skillList;
        public Weapon(
            string name,
            Potential potential,
            WeaponType weaponType,
            List<Skill> skillList,
            LevelSystem levelSystem
        )
        {
            this.id = Guid.NewGuid();
            this.name = name;
            this.potential = potential;
            this.weaponType = weaponType;
            this.equipState = false;
            this.skillList = skillList;
            this.levelSystem = levelSystem;
        }
        //武器裝備狀態切換
        public void changeEquipState(bool value)
        {
            this.equipState = value;
        }
        //取得素質方法
        private double getRealPotential(
            double initialPotential,
            double ratio
        )
        {
            double total = initialPotential;
            total += ratio * levelSystem.potentialLevelConstant;
            return total;
        }
        //計算後力量
        public double strength
        {
            get
            {
                return getRealPotential(potential.strength, potential.strengthRatio);
            }
        }
        //計算後敏捷
        public double agility
        {
            get
            {
                return getRealPotential(potential.agility, potential.agilityRatio);
            }
        }
        //計算後靈巧
        public double perception
        {
            get
            {
                return getRealPotential(potential.perception, potential.perceptionRatio);
            }
        }
        //計算後體質
        public double vitality
        {
            get
            {
                return getRealPotential(potential.vitality, potential.vitalityRatio);
            }
        }
        //計算後智慧
        public double intelligence
        {
            get
            {
                return getRealPotential(potential.intelligence, potential.intelligenceRatio);
            }
        }
        //計算後精神
        public double mentality
        {
            get
            {
                return getRealPotential(potential.mentality, potential.mentalityRatio);
            }
        }
        //從類型取得素質
        public double getPotential(PotentialType potentialType)
        {
            switch (potentialType)
            {
                case PotentialType.strength:
                    return strength;
                case PotentialType.agility:
                    return agility;
                case PotentialType.perception:
                    return perception;
                case PotentialType.vitality:
                    return vitality;
                case PotentialType.intelligence:
                    return intelligence;
                case PotentialType.mentality:
                    return mentality;
                default:
                    return 0;
            }
        }
    }
}