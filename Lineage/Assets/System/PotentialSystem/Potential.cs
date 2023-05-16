using System;
using System.Collections;
using System.Collections.Generic;
using UtilSystem;

namespace PotentialSystem
{
    public class Potential
    {
        //力量
        public double strength;
        //體質
        public double vitality;
        //敏捷
        public double agility;
        //感知
        public double perception;
        //智慧
        public double intelligence;
        //精神
        public double mentality;
        //力量等級比率
        public double strengthRatio;
        //體質等級比率
        public double vitalityRatio;
        //敏捷等級比率
        public double agilityRatio;
        //感知等級比率
        public double perceptionRatio;
        //智慧等級比率
        public double intelligenceRatio;
        //精神等級比率
        public double mentalityRatio;
        //力量表現評比
        public RankType strengthRank;
        //體質表現評比
        public RankType vitalityRank;
        //敏捷表現評比
        public RankType agilityRank;
        //感知表現評比
        public RankType perceptionRank;
        //智慧表現評比
        public RankType intelligenceRank;
        //精神表現評比
        public RankType mentalityRank;


        public Potential(
            double strength,
            double vitality,
            double agility,
            double perception,
            double intelligence,
            double mentality,
            double strengthRatio,
            double vitalityRatio,
            double perceptionRatio,
            double agilityRatio,
            double intelligenceRatio,
            double mentalityRatio
        )
        {
            this.strength = strength;
            this.vitality = vitality;
            this.agility = agility;
            this.perception = perception;
            this.intelligence = intelligence;
            this.mentality = mentality;
            this.strengthRatio = strengthRatio;
            this.vitalityRatio = vitalityRatio;
            this.perceptionRatio = perceptionRatio;
            this.agilityRatio = agilityRatio;
            this.intelligenceRatio = intelligenceRatio;
            this.mentalityRatio = mentalityRatio;
            strengthRank = ratioToRankToRank(strengthRatio);
            vitalityRank = ratioToRankToRank(vitalityRatio);
            perceptionRank = ratioToRankToRank(perceptionRatio);
            agilityRank = ratioToRankToRank(agilityRatio);
            intelligenceRank = ratioToRankToRank(intelligenceRatio);
            mentalityRank = ratioToRankToRank(mentalityRatio);
        }
        public static RankType ratioToRankToRank(double ratio)
        {
            double defaultGap = 0.5;
            double gap = 0.2;
            if (ratio <= defaultGap)
            {
                return RankType.E;
            }
            else if (ratio > defaultGap && ratio <= defaultGap + gap)
            {
                return RankType.D;
            }
            else if (ratio > defaultGap + gap && ratio <= defaultGap + gap * 2)
            {
                return RankType.C;
            }
            else if (ratio > defaultGap + gap * 2 && ratio <= defaultGap + gap * 3)
            {
                return RankType.B;
            }
            else if (ratio > defaultGap + gap * 3 && ratio <= defaultGap + gap * 4)
            {
                return RankType.A;
            }
            else if (ratio > defaultGap + gap * 4 && ratio <= defaultGap + gap * 5)
            {
                return RankType.S;
            }
            else if (ratio > defaultGap + gap * 5 && ratio <= defaultGap + gap * 6)
            {
                return RankType.SS;
            }
            else
            {
                return RankType.SSS;
            }
        }
    }
}