using HeroSystem;
using System;
using System.Collections;
using System.Collections.Generic;
using SoldierSystem;
using UtilSystem;
using SkillSystem;
using WeaponSystem;

namespace PartySystem
{
    public class Party
    {
        //部隊名稱
        public string name;
        //隊長
        public Hero hero;
        //兵團
        public List<Soldier> soldiers;
        //技能
        public List<Skill> skillList ;
        //武器
        public Weapon weapon;

        public Party(string name, Hero hero, List<Soldier> soldiers,Weapon weapon)
        {
            this.name = name;
            this.hero = hero;
            this.soldiers = soldiers;
            this.skillList = hero.skillList;
            this.weapon = weapon;
        }

        //取得素質方法
        private double getRealPotential(
            PotentialType potentialType
        )
        {
            double totalPotential = 0;
            totalPotential += hero.getPotential(potentialType) * 0.4;
            totalPotential += weapon.getPotential(potentialType) * 0.3;
            soldiers.ForEach(soldier =>
            {
                totalPotential += soldier.getPotential(potentialType) * 0.06;
            });
            return totalPotential;
        }
        //計算後力量
        public double strength
        {
            get
            {
                return getRealPotential(PotentialType.strength);
            }
        }
        //計算後敏捷
        public double agility
        {
            get
            {
                return getRealPotential(PotentialType.agility);
            }
        }
        //計算後靈巧
        public double dexterity
        {
            get
            {
                return getRealPotential(PotentialType.dexterity);
            }
        }
        //計算後體質
        public double vitality
        {
            get
            {
                return getRealPotential(PotentialType.vitality);
            }
        }
        //計算後智慧
        public double intelligence
        {
            get
            {
                return getRealPotential(PotentialType.intelligence);
            }
        }
        //計算後精神
        public double mentality
        {
            get
            {
                return getRealPotential(PotentialType.mentality);
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