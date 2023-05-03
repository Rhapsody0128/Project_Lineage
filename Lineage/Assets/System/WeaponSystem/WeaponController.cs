using PotentialSystem;
using SkillSystem;
using System;
using System.Collections;
using System.Collections.Generic;
using UtilSystem;

namespace WeaponSystem
{
    public class WeaponController
    {
        //隨機武器
        public static Weapon getRandomWeapon()
        {
            Potential potential = PotentialController.getRandomPotential();
            WeaponType weaponType = getRandomWeaponType();
            string name = getRandomName(weaponType);
            List<Skill> skillList = SkillController.getRandomSkillList(weaponType);
            Weapon newWeapon = new Weapon(name, potential, weaponType, skillList, new LevelSystem());
            return newWeapon;
        }
        public static Weapon getRandomWeapon(WeaponType weaponType)
        {
            Potential potential = PotentialController.getRandomPotential();
            string name = getRandomName(weaponType);
            List<Skill> skillList = SkillController.getRandomSkillList(weaponType);
            Weapon newWeapon = new Weapon(name, potential, weaponType, skillList, new LevelSystem());
            return newWeapon;
        }
        //隨機某種類武器名
        private static string getRandomName(WeaponType weaponType)
        {
            string name = weaponType.ToString();
            return name;
        }
        //隨機某武器種類
        private static WeaponType getRandomWeaponType()
        {
            return Util.getRandomFromEnum<WeaponType>();
        }
    }
}