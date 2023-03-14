using UtilSystem;
using CharacterSystem;

namespace TroopSystem {
    public class Troop {
      public string name ;
      public Character leader ;
      public List<Character> members ;
      public Troop(string name,Character leader,List<Character> members){
        this.name = name ;
        this.leader = leader ;  
        this.members = members ;
      }
      public double moveSpeed {
        get { 
          double totalAgility = 0 ; 
          foreach (Character member in members){
            totalAgility += member.agility ;
          }
          return totalAgility; 
        } 
      } 
      public double totalMilitary {
        get { 
          double totalMilitary = 0 ; 
          foreach (Character member in members){
              totalMilitary += member.military ;
          }
          return totalMilitary ;
        }
      } 
    }
}