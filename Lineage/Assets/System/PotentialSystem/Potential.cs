using System;
using System.Collections;
using System.Collections.Generic;
using UtilSystem;

namespace PotentialSystem {
    public class Potential {
      public double strength;
      public double vitality;
      public double agility;
      public double dexterity;
      public double intelligence;
      public double mentality;
      public double strRatio;
      public double vitRatio;
      public double dexRatio;
      public double agiRatio;
      public double intRatio;
      public double menRatio;
      public RankType strRank;
      public RankType vitRank;
      public RankType dexRank;
      public RankType agiRank;
      public RankType intRank;
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
    ) {
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
    public RankType ratioToRankToRank(double ratio){
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