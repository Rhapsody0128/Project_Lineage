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
        //public static void getMarriage(Hero self, Hero target)
        //{
        //    bornChild(self, target);
        //}
        //生子
        //public static Hero bornChild(Hero self, Hero target)
        //{

        //}

    }
}