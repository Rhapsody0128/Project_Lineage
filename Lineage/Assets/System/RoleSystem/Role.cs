using PotentialSystem;
using SkillSystem;
using System;
using System.Collections;
using System.Collections.Generic;
using UtilSystem;
using WeaponSystem;

namespace RoleSystem
{
    public class Role
    {
        //id
        private Guid id;
        //名字
        public string name;
        //姓氏
        public string lastName;
        //素質
        public Potential potential;
        //手持武器
        public Weapon? holdingWeapon;
        //習得技能
        public List<Skill> skill;
        //等級系統
        public LevelSystem levelSystem;

        public Role(
            string name,
            string lastName,
            Potential potential,
            List<Skill> skill,
            LevelSystem levelSystem
        )
        {
            this.name = name;
            this.lastName = lastName;
            this.id = Guid.NewGuid();
            this.potential = potential;
            this.skill = skill;
            this.levelSystem = levelSystem;
        }
        //裝備武器
        public void equipWeapon(Weapon weapon)
        {

            if (weapon.equipState is true)
            {
                return;
                // throw new InvalidOperationException("weapon has been equiped");
            }
            if (this.holdingWeapon is not null)
            {
                this.holdingWeapon.changeEquipState(false);
            }
            this.holdingWeapon = weapon;
            this.holdingWeapon.changeEquipState(true);

        }
        //卸除武器
        public void unEquipWeapon()
        {
            if (this.holdingWeapon is null)
            {
                return;
                // throw new InvalidOperationException("no weapon to unEquip");
            }
            this.holdingWeapon.changeEquipState(false);
            this.holdingWeapon = null;
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
        //計算後力量
        public double strength
        {
            get
            {
                double weaponPotential = 0;
                if (holdingWeapon != null)
                {
                    weaponPotential = holdingWeapon.strength;
                }
                return getRealPotential(potential.strength, potential.strRatio, weaponPotential);
            }
        }
        //計算後敏捷
        public double agility
        {
            get
            {
                double weaponPotential = 0;
                if (holdingWeapon != null)
                {
                    weaponPotential = holdingWeapon.agility;
                }
                return getRealPotential(potential.agility, potential.agiRatio, weaponPotential);
            }
        }
        //計算後靈巧
        public double dexterity
        {
            get
            {
                double weaponPotential = 0;
                if (holdingWeapon != null)
                {
                    weaponPotential = holdingWeapon.dexterity;
                }
                return getRealPotential(potential.dexterity, potential.dexRatio, weaponPotential);
            }
        }
        //計算後體質
        public double vitality
        {
            get
            {
                double weaponPotential = 0;
                if (holdingWeapon != null)
                {
                    weaponPotential = holdingWeapon.vitality;
                }
                return getRealPotential(potential.vitality, potential.vitRatio, weaponPotential);
            }
        }
        //計算後智慧
        public double intelligence
        {
            get
            {
                double weaponPotential = 0;
                if (holdingWeapon != null)
                {
                    weaponPotential = holdingWeapon.intelligence;
                }
                return getRealPotential(potential.intelligence, potential.intRatio, weaponPotential);
            }
        }
        //計算後精神
        public double mentality
        {
            get
            {
                double weaponPotential = 0;
                if (holdingWeapon != null)
                {
                    weaponPotential = holdingWeapon.mentality;
                }
                return getRealPotential(potential.mentality, potential.menRatio, weaponPotential);
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