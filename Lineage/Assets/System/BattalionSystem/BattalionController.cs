using RoleSystem;
using System;
using System.Collections;
using System.Collections.Generic;
using TroopSystem;
using UtilSystem;

namespace BattalionSystem
{
    public class BattalionController
    {
        //取得隨機部隊
        static public Battalion getRandomBattalion()
        {
            var leader = RoleController.getRandomRole();
            var troops = new List<Troop>();
            for (int i = 0; i < 5; i++)
            {
                troops.Add(TroopController.getRandomTroop());
            }
            var battalion = new Battalion(leader.lastName + "的部隊", leader, troops);
            return battalion;
        }
    }
}