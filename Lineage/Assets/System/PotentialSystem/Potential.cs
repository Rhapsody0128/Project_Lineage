using System;
using System.Collections;
using System.Collections.Generic;
using UtilSystem;

namespace PotentialSystem {
    public class Potential {
        //力量
        public double strength;
        //體質
        public double vitality;
        //敏捷
        public double agility;
        //靈巧
        public double dexterity;
        //智慧
        public double intelligence;
        //精神
        public double mentality;
        //力量等級比率
        public double strRatio;
        //體質等級比率
        public double vitRatio;
        //敏捷等級比率
        public double agiRatio;
        //靈巧等級比率
        public double dexRatio;
        //智慧等級比率
        public double intRatio;
        //精神等級比率
        public double menRatio;
        //力量表現評比
        public RankType strRank;
        //體質表現評比
        public RankType vitRank;
        //敏捷表現評比
        public RankType agiRank;
        //靈巧表現評比
        public RankType dexRank;
        //智慧表現評比
        public RankType intRank;
        //精神表現評比
        public RankType menRank;


        public Potential(
            (
                double strength,
                double vitality,
                double agility,
                double dexterity,
                double intelligence,
                double mentality,
                double strRatio,
                double vitRatio,
                double dexRatio,
                double agiRatio,
                double intRatio,
                double menRatio
            ) potentialData
        )   {
              strength = potentialData.strength;
              vitality = potentialData.vitality;
              agility = potentialData.agility;
              dexterity = potentialData.dexterity;
              intelligence = potentialData.intelligence;
              mentality = potentialData.mentality;
              strRatio = potentialData.strRatio;
              vitRatio = potentialData.vitRatio;
              dexRatio = potentialData.dexRatio;
              agiRatio = potentialData.agiRatio;
              intRatio = potentialData.intRatio;
              menRatio = potentialData.menRatio;
              strRank = ratioToRankToRank(potentialData.strRatio);
              vitRank = ratioToRankToRank(potentialData.vitRatio);
              dexRank = ratioToRankToRank(potentialData.dexRatio);
              agiRank = ratioToRankToRank(potentialData.agiRatio);
              intRank = ratioToRankToRank(potentialData.intRatio);
              menRank = ratioToRankToRank(potentialData.menRatio);
            }
    public static RankType ratioToRankToRank(double ratio){
        double defaultGap = 0.5;
        double gap = 0.2;
        if (ratio <= defaultGap) {
          return RankType.E;
        } else if (ratio > defaultGap && ratio <= defaultGap + gap) {
          return RankType.D;
        } else if (ratio > defaultGap + gap && ratio <= defaultGap + gap * 2) {
          return RankType.C;
        } else if (ratio > defaultGap + gap * 2 && ratio <= defaultGap + gap * 3) {
          return RankType.B;
        } else if (ratio > defaultGap + gap * 3 && ratio <= defaultGap + gap * 4) {
          return RankType.A;
        } else if (ratio > defaultGap + gap * 4 && ratio <= defaultGap + gap * 5) {
          return RankType.S;
        } else if (ratio > defaultGap + gap * 5 && ratio <= defaultGap + gap * 6) {
          return RankType.SS;
        } else {
          return RankType.SSS;
        }
      }
    }
}