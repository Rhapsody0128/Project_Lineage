using System;
using System.Collections;
using System.Collections.Generic;
using UtilSystem;
using PartySystem;
using FormationSystem;
using Microsoft.VisualBasic;


namespace TroopSystem
{
    public class Troop
    {
        //軍團名稱
        public string name;
        //全軍團
        public List<Party> parties;
        //移動速度常數
        public double moveSpeedConsant = 0.01;
        //陣形
        public Formation formation;
        

        public Troop(
            string name,
            List<Party> parties,
            Formation formation
        )
        {
            this.name = name;
            this.parties = parties;
            this.formation = formation;
        }

        //軍團長
        public Party partyLeader
        {
            get
            {
                return parties[0];
            }
        }

        //移動速度
        public double moveSpeed {
            get {
                return perception * moveSpeedConsant;
            }
        }

        //取得素質方法
        private double getRealPotential(
            PotentialType potentialType
        )
        {
            double totalPotential = 0;
            parties.ForEach(party => {
                totalPotential += party.getPotential(potentialType);
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