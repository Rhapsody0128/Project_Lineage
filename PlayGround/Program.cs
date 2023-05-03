using UtilSystem;
using BattleSystem;
using PartySystem;
using TroopSystem;
using System;
using PotentialSystem;
using HeroSystem;
using SkillSystem;
using WeaponSystem;

internal class Program
{
    private static void Main(string[] args)
    {
        var a = TroopController.getRandomTroop();
        var b = TroopController.getRandomTroop();
        var battle = new Battle(a, b);
        Console.WriteLine(a.partyLeader.hero.potential.agility);
        Console.WriteLine(a.partyLeader.hero.agility);
        Console.WriteLine(a.partyLeader.agility);
        Console.WriteLine(a.agility);
        Console.WriteLine(battle.selfPartyLeader.party.agility);
        Console.WriteLine(battle.selfPartyLeader.agility);
        Console.WriteLine("--戰鬥完升級後--");
        a.partyLeader.hero.potential.agility = 123;
        Console.WriteLine(a.partyLeader.hero.potential.agility);
        Console.WriteLine(a.partyLeader.hero.agility);
        Console.WriteLine(a.partyLeader.agility);
        Console.WriteLine(a.agility);
        Console.WriteLine(battle.selfPartyLeader.party.agility);
        Console.WriteLine(battle.selfPartyLeader.agility);
    }
}