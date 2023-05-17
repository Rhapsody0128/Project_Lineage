using PotentialSystem;
using SkillSystem;
using System;
using System.Collections;
using System.Collections.Generic;
using UtilSystem;

namespace SoldierSystem
{
    public class Soldier
    {
        //兵團名
        public string name;
        //士兵最大數
        public int soldiersCountMax;
        //死亡士兵數
        public int deathSoldiersCount;
        //受傷士兵數
        public int woundedSoldiersCount;
        //素質
        public Potential potential;
        //技能
        public List<Skill> skillList = new List<Skill>();
        //等級
        public LevelSystem levelSystem = new LevelSystem();

        public Soldier(
          string name,
          Potential potential,
          List<Skill> skillList,
          LevelSystem levelSystem
        )
        {
            this.name = name;
            this.soldiersCountMax = 200;
            this.deathSoldiersCount = 0;
            this.woundedSoldiersCount = 0;
            this.potential = potential;
            this.skillList = skillList;
            this.levelSystem = levelSystem ?? new LevelSystem();
        }

        //待命中士兵數量
        public int soldiersCount {
            get {
                return this.soldiersCountMax - this.deathSoldiersCount - this.woundedSoldiersCount;
            }
        }
        //是否有可用士兵
        public bool isDisabled {
            get {
                return soldiersCount <= 0;
            }
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