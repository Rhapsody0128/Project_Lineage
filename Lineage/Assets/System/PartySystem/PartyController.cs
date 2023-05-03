using HeroSystem;
using System;
using System.Collections;
using System.Collections.Generic;
using SoldierSystem;
using UtilSystem;
using WeaponSystem;

namespace PartySystem
{
    public class PartyController
    {
        //取得隨機部隊
        static public Party getRandomParty()
        {
            var hero = HeroController.getRandomHero();
            var soldiers = new List<Soldier>();
            for (int i = 0; i < 5; i++)
            {
                soldiers.Add(SoldierController.getRandomSoldier());
            }
            var weapon = WeaponController.getRandomWeapon();
            var party = new Party(hero.name + "隊", hero, soldiers, weapon);
            return party;
        }
    }
}