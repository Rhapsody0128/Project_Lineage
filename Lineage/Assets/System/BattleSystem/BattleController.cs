using System;
using System.Collections;
using System.Collections.Generic;
using UtilSystem;
using TroopSystem;

namespace BattleSystem
{
    public class BattleController
    {
        //取得隨機戰鬥
        static public Battle getRandomBattle()
        {
            Troop selfTroop = TroopController.getRandomTroop();
            Troop enemyTroop = TroopController.getRandomTroop();
            Battle battle = new Battle(selfTroop, enemyTroop);
            return battle;
        }
    }
    
}