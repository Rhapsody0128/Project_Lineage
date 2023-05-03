using PotentialSystem;
using SkillSystem;
using System;
using System.Collections;
using System.Collections.Generic;
using UtilSystem;
using WeaponSystem;

namespace HeroSystem
{
    public class Hero
    {
        //id
        public Guid id;
        //名字
        public string name;
        //姓氏
        public string lastName;
        //素質
        public Potential potential;
        //習得技能
        public List<Skill> skillList;
        //等級系統
        public LevelSystem levelSystem;

        public Hero(
            string name,
            string lastName,
            Potential potential,
            List<Skill> skillList,
            LevelSystem levelSystem
        )
        {
            this.id = Guid.NewGuid();
            this.name = name;
            this.lastName = lastName;
            this.potential = potential;
            this.skillList = skillList;
            this.levelSystem = levelSystem;
        }
        //獲得經驗值
        public void gainExp(int expNumber)
        {
            levelSystem.gainExp(expNumber);
        }
        //取得素質方法
        private double getRealPotential(
            double initialPotential,
            double ratio,
            double weaponPotential
        )
        {
            double total = initialPotential;
            total += ratio * levelSystem.potentialLevelConstant;
            total += weaponPotential;
            return total;
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
                return getRealPotential(potential.strength, potential.strRatio);
            }
        }
        //計算後敏捷
        public double agility
        {
            get
            {
                return getRealPotential(potential.agility, potential.agiRatio);
            }
        }
        //計算後靈巧
        public double dexterity
        {
            get
            {
                return getRealPotential(potential.dexterity, potential.dexRatio);
            }
        }
        //計算後體質
        public double vitality
        {
            get
            {
                return getRealPotential(potential.vitality, potential.vitRatio);
            }
        }
        //計算後智慧
        public double intelligence
        {
            get
            {
                return getRealPotential(potential.intelligence, potential.intRatio);
            }
        }
        //計算後精神
        public double mentality
        {
            get
            {
                return getRealPotential(potential.mentality, potential.menRatio);
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
                case PotentialType.dexterity:
                    return dexterity;
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