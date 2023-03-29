using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UtilSystem;
using SkillSystem;
using PotentialSystem;

namespace WeaponSystem {
    public class WeaponController {
        public static Weapon getRandomWeapon(){
            Potential potential = PotentialController.getRandomPotential();
            WeaponType weaponType = getRandomWeaponType();
            string name = getRandomName(weaponType);
            List<Skill>? skill = SkillController.getRandomSkill(weaponType);
            Weapon newWeapon = new Weapon(name,potential,weaponType,skill);
            return newWeapon;
        }

        private static string getRandomName(WeaponType weaponType){
            string name = weaponType.ToString();
            return name;
        }
        private static WeaponType getRandomWeaponType(){
                return Util.getRandomFromEnum<WeaponType>() ;
        }
    }
}