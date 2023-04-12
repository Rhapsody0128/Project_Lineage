using System;
using System.Collections;
using System.Collections.Generic;
using UtilSystem;
using BattalionSystem;


namespace RegimentSystem
{
    public class Regiment
    {
        //軍團名稱
        public string name;
        //兵團
        public List<Battalion> battalions;
        //移動速度常數
        public double moveSpeedConsant = 0.01;

        public Regiment(string name,List<Battalion> battalions)
        {
            this.name = name;
            this.battalions = battalions; 
        }

        //移動速度
        public double moveSpeed {
            get {
                return dexterity * moveSpeedConsant;
            }
        }

        //取得素質方法
        private double getRealPotential(
            PotentialType potentialType
        )
        {
            double totalPotential = 0;
            battalions.ForEach(battalion => {
                totalPotential += battalion.getPotential(potentialType);
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