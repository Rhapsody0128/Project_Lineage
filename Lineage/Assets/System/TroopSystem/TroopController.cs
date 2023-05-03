using PartySystem;
using System;
using System.Collections;
using System.Collections.Generic;
using UtilSystem;


namespace TroopSystem
{
    public class TroopController
    {
        //取得隨機軍團
        static public Troop getRandomTroop()
        {

            Party partyLeader = PartyController.getRandomParty();
            var parties = new List<Party>();
            parties.Add(partyLeader);
            for (int i = 0; i < 4; i++)
            {
                Party party = PartyController.getRandomParty();
                parties.Add(party);
            }
            var troop = new Troop("隨機軍團", partyLeader, parties);
            return troop;
        }
    }
}