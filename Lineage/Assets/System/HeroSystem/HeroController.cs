using PotentialSystem;
using SkillSystem;
using System;
using System.Collections;
using System.Collections.Generic;
using UtilSystem;

namespace HeroSystem
{
    public class HeroController
    {
        //隨機角色
        public static Hero getRandomHero()
        {
            var name = Util.getRandomFromEnum<MaleHeroName>().ToString();
            var lastName = Util.getRandomFromEnum<MaleHeroLastName>().ToString();
            var potential = PotentialController.getRandomPotential();
            var skillList = SkillController.getRandomSkillList();
            var newHero = new Hero(name, lastName, potential, skillList, new LevelSystem());
            return newHero;
        }
        //結婚
        public static void getMarriage(Hero self, Hero target)
        {
            bornChild(self, target);
        }
        //生子
        public static Hero bornChild(Hero self, Hero target)
        {
            var potentialList = (
                strength: 102,
                vitality: 102,
                agility: 102,
                dexterity: 31,
                intelligence: 5,
                mentality: 6,
                strRatio: 1.12,
                vitRatio: 2.1,
                dexRatio: 1.05,
                agiRatio: 0.7,
                intRatio: 0.5,
                menRatio: 0.6
            );
            Potential potential = new Potential(potentialList);
            List<Skill> skills = new List<Skill>();
            Hero child = new Hero("newChild", "lastName", potential, skills, new LevelSystem());
            return child;
        }

    }
}