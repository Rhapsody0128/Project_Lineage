﻿using UtilSystem;
using BattleSystem;
using PartySystem;
using TroopSystem;
using System;
using PotentialSystem;
using HeroSystem;
using SkillSystem;
using WeaponSystem;


//Console.WriteLine();
internal class Program
{
    private static void Main(string[] args)
    {
        var troop = TroopController.getRandomTroop();
        troop.parties.ForEach(party =>
        {
            Console.WriteLine(party.name);
            Console.WriteLine(party.weapon);
        });
    }
}