namespace UtilSystem {
    public class Potential {
      public double strength;
      public double vitality;
      public double agility;
      public double dexterity;
      public double intelligence;
      public double mentality;
      public double StrRatio;
      public double VitRatio;
      public double DexRatio;
      public double AgiRatio;
      public double IntRatio;
      public double MenRatio;
      public string StrRank;
      public string VitRank;
      public string DexRank;
      public string AgiRank;
      public string IntRank;
      public string MenRank;

    public Potential(
      (
        double strength,
        double vitality,
        double agility,
        double dexterity,
        double intelligence,
        double mentality,
        double StrRatio,
        double VitRatio,
        double DexRatio,
        double AgiRatio,
        double IntRatio,
        double MenRatio
        ) potentialData
    ) {
        strength = potentialData.strength;
        vitality = potentialData.vitality;
        agility = potentialData.agility;
        dexterity = potentialData.dexterity;
        intelligence = potentialData.intelligence;
        mentality = potentialData.mentality;
        StrRatio = potentialData.StrRatio;
        VitRatio = potentialData.VitRatio;
        DexRatio = potentialData.DexRatio;
        AgiRatio = potentialData.AgiRatio;
        IntRatio = potentialData.IntRatio;
        MenRatio = potentialData.MenRatio;
        StrRank = ratioToRankToRank(potentialData.StrRatio);
        VitRank = ratioToRankToRank(potentialData.VitRatio);
        DexRank = ratioToRankToRank(potentialData.DexRatio);
        AgiRank = ratioToRankToRank(potentialData.AgiRatio);
        IntRank = ratioToRankToRank(potentialData.IntRatio);
        MenRank = ratioToRankToRank(potentialData.MenRatio);
      }
    public string ratioToRankToRank(double ratio){
        double defaultGap = 0.5;
        double gap = 0.2;
        if (ratio <= defaultGap) {
          return "E";
        } else if (ratio > defaultGap && ratio <= defaultGap + gap) {
          return "D";
        } else if (ratio > defaultGap + gap && ratio <= defaultGap + gap * 2) {
          return "C";
        } else if (ratio > defaultGap + gap * 2 && ratio <= defaultGap + gap * 3) {
          return "B";
        } else if (ratio > defaultGap + gap * 3 && ratio <= defaultGap + gap * 4) {
          return "A";
        } else if (ratio > defaultGap + gap * 4 && ratio <= defaultGap + gap * 5) {
          return "S";
        } else if (ratio > defaultGap + gap * 5 && ratio <= defaultGap + gap * 6) {
          return "SS";
        } else {
          return "SSS";
        }
      }
    }
}