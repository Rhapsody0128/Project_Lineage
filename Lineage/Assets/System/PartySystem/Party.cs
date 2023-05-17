using HeroSystem;
using System;
using System.Collections;
using System.Collections.Generic;
using SoldierSystem;
using UtilSystem;
using SkillSystem;
using WeaponSystem;
using FormationSystem;

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
        public List<Skill> skillList;
        //在陣形中佔據的位置資訊
        public FormationCell? formationCell;

        public Party(string name, Hero hero, List<Soldier> soldiers)
        {
            this.name = name;
            this.hero = hero;
            this.soldiers = soldiers;
            this.skillList = hero.skillList;
        }

        public void setFomationCell(FormationCell formationCell)
        {
            this.formationCell = formationCell;
        }
        // 陣形中陣形役(攻擊位,防禦位等等)
        public SkillType? poistionSkillType
        {
            get
            {
                if (formationCell != null)
                {
                    return formationCell.poistionSkillType;
                }
                else
                {
                    return null;
                }
            }
        }
        //陣形中取得的武器
        public Weapon? weapon
        {
            get
            {
                if (formationCell != null)
                {
                    return formationCell.weapon;
                }
                else
                {
                    return null;
                }
            }
        }
        //全部待命中士兵
        public int totalSoilderCount
        {
            get {
                return soldiers.Sum(soldiers => soldiers.soldiersCount );
            }
        }
        //全部受傷士兵
        public int totalWondedSoilderCount
        {
            get
            {
                return soldiers.Sum(soldiers => soldiers.woundedSoldiersCount);
            }
        }
        //全部無法行動士兵
        public bool totalSoliderIsDisabled
        {
            get {
                return soldiers.All(soldiers => soldiers.isDisabled);
            }
        }

        //取得素質方法
        private double getRealPotential(
            PotentialType potentialType
        )
        {
            double totalPotential = 0;
            totalPotential += hero.getPotential(potentialType) * 0.4;
            if (weapon != null) {
                totalPotential += weapon.getPotential(potentialType) * 0.3;
            }
            soldiers.ForEach(soldier =>
            {
                if (!soldier.isDisabled) {
                    totalPotential += soldier.getPotential(potentialType) * 0.06;
                }
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
        public double perception
        {
            get
            {
                return getRealPotential(PotentialType.perception);
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