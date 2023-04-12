using PotentialSystem;
using SkillSystem;
using System;
using System.Collections;
using System.Collections.Generic;
using UtilSystem;

namespace RoleSystem
{
    public class RoleController
    {
        //隨機角色
        public static Role getRandomRole()
        {
            var name = Util.getRandomFromEnum<MaleRoleName>().ToString();
            var lastName = Util.getRandomFromEnum<MaleRoleLastName>().ToString();
            var potential = PotentialController.getRandomPotential();
            var skill = SkillController.getRandomSkill(RankType.E);
            var newRole = new Role(name, lastName, potential, skill, new LevelSystem());
            return newRole;
        }
        //結婚
        public static void getMarriage(Role self, Role target)
        {
            bornChild(self, target);
        }
        //生子
        public static Role bornChild(Role self, Role target)
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
            Role child = new Role("newChild", "lastName", potential, skills, new LevelSystem());
            return child;
        }

    }
}