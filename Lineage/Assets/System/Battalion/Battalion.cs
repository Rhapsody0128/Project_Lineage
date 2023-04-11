using System;
using System.Collections;
using System.Collections.Generic;
using UtilSystem;
using RoleSystem;
using TroopSystem;

namespace BattalionSystem {
    public class Battalion {
      public string name ;
      public Role leader ;
      public List<Troop> troops = new List<Troop>();
      public Battalion(string name,Role leader,List<Troop> troops){
        this.name = name ;
        this.leader = leader ;  
        this.troops = troops ;
      }
      public double moveSpeed {
        get { 
          double totalAgility = 0 ; 
          foreach (Troop troop in troops){
            totalAgility += troop.agility ;
          }
          return totalAgility; 
        } 
      } 
      public double totalSoldiersCount {
        get { 
          double totalSoldiersCount = 0 ; 
          foreach (Troop troop in troops){
              totalSoldiersCount += troop.soldiersCount ;
          }
          return totalSoldiersCount ;
        }
      } 
    }
}