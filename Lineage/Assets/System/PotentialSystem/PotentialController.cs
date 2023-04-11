using System;
using System.Collections;
using System.Collections.Generic;
using UtilSystem;


namespace PotentialSystem {
    public class PotentialController {
        public static Potential getRandomPotential(){
            var potentialList = (
                strength: Util.getRandom(0,50),
                vitality: Util.getRandom(0,50),
                agility: Util.getRandom(0,50),
                dexterity: Util.getRandom(0,50),
                intelligence: Util.getRandom(0,50),
                mentality: Util.getRandom(0,50),
                strRatio: Util.getRandom(0.5,2),
                vitRatio: Util.getRandom(0.5,2),
                dexRatio: Util.getRandom(0.5,2),
                agiRatio: Util.getRandom(0.5,2),
                intRatio: Util.getRandom(0.5,2),
                menRatio: Util.getRandom(0.5,2)
            ) ;
            Potential potential = new Potential(potentialList);
            return potential;
        }
    }
}