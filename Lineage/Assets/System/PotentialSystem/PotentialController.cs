using System;
using System.Collections;
using System.Collections.Generic;
using UtilSystem;


namespace PotentialSystem {
    public class PotentialController {
        //取得隨機素質
        public static Potential getRandomPotential(){
            Potential potential = new Potential(
                Util.getRandom(0, 50),
                Util.getRandom(0, 50),
                Util.getRandom(0, 50),
                Util.getRandom(0, 50),
                Util.getRandom(0, 50),
                Util.getRandom(0, 50),
                Util.getRandom(0.5, 2),
                Util.getRandom(0.5, 2),
                Util.getRandom(0.5, 2),
                Util.getRandom(0.5, 2),
                Util.getRandom(0.5, 2),
                Util.getRandom(0.5, 2)
            );
            return potential;
        }
    }
}