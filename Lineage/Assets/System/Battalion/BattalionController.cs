using System;
using System.Collections;
using System.Collections.Generic;
using UtilSystem;
using RoleSystem;
using TroopSystem;

namespace BattalionSystem {
    public class BattalionController{
        static public Battalion getRandomBattalion(){
            var leader = RoleController.getRandomRole();
            var troops = new List<Troop>() ; 
            for (int i = 0; i < 5; i++){
                troops.Add(TroopController.getRandomTroop());
            }
            var battalion = new Battalion(leader.lastName + "的部隊",leader,troops) ;
            return battalion ;
        }
    }
}