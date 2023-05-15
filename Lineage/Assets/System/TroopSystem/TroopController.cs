using PartySystem;
using FormationSystem;
using System;
using System.Collections;
using System.Collections.Generic;
using UtilSystem;
using WeaponSystem;


namespace TroopSystem
{
    public class TroopController
    {
        //取得隨機軍團
        static public Troop getRandomTroop()
        {

            Party partyLeader = PartyController.getRandomParty();
            var parties = new List<Party>();
            var formation = FormationController.getRandomFormation();
            for (int i = 0; i < 6; i++)
            {
                Party party = PartyController.getRandomParty();
                Weapon weapon = WeaponController.getRandomWeapon();
                FormationCell formationCell = formation.formationCellList[i];
                formationCell.setWeapon(weapon);
                party.setFomationCell(formationCell);
                parties.Add(party);
            }
            
            var troop = new Troop("隨機軍團", parties, formation);
            return troop;
        }
    }
}