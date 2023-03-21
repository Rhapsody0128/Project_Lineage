using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UtilSystem;
using RoleSystem;

namespace TroopSystem {
    public class TroopController{
        static public Troop getRandomTroop(){
            List<Role> members = new List<Role>();
            for (int i = 0; i < 6; i++){
                members.Add(RoleController.getRandomRole());
            }
            var troop = new Troop(members[0].lastName + "的部隊" + members.Count,members[0],members) ;
            return troop ;
        }
    }
}