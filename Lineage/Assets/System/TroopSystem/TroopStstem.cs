using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UtilSystem;
using RoleSystem;

namespace TroopSystem {
    public class Troop {
      public string name ;
      public Role leader ;
      public List<Role> members = new List<Role>();
      public Troop(string name,Role leader,List<Role> members){
        this.name = name ;
        this.leader = leader ;  
        this.members = members ;
      }
      public double moveSpeed {
        get { 
          double totalAgility = 0 ; 
          foreach (Role member in members){
            totalAgility += member.agility ;
          }
          return totalAgility; 
        } 
      } 
      public double totalMilitary {
        get { 
          double totalMilitary = 0 ; 
          foreach (Role member in members){
              totalMilitary += member.military ;
          }
          return totalMilitary ;
        }
      } 
    }
}