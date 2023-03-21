using System.Collections.Generic;
using UtilSystem;
using CharacterSystem;

namespace TroopSystem {
    public class TroopController{
        static public Troop getRandomTroop(){
            List<Character> members = new List<Character>();
            for (int i = 0; i < 6; i++){
                members.Add(CharacterController.getRandomCharacter());
            }
            var troop = new Troop(members[0].lastName + "的部隊" + members.Count,members[0],members) ;
            return troop ;
        }
    }
}