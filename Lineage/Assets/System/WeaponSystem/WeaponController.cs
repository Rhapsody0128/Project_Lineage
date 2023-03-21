using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UtilSystem;
using SkillSystem;
#nullable enable

namespace WeaponSystem {
    public class WeaponController {
        public static Weapon getRandomWeapon(){
            Potential potential = getRandomPotential();
            WeaponType weaponType = getRandomWeaponType();
            string name = getRandomName(weaponType);
            List<Skill>? skill = getRandomSkill(weaponType);
            Weapon newWeapon = new Weapon(name,potential,weaponType,skill);
            return newWeapon;
        }

        private static string getRandomName(WeaponType weaponType){
            string name = weaponType.ToString();
            return name;
        }
        private static List<Skill>? getRandomSkill(WeaponType weaponType){
            List<Skill>? skill = SkillController.getSkill(weaponType);
            if(skill != null){
                var randomSkill = skill[Util.getRandom(0,skill.Count)] ;
                randomSkill.state = true ;
                return new List<Skill>(){randomSkill} ;
            }else{
                return null;
            }
        }
        private static WeaponType getRandomWeaponType(){
                return Util.getRandomFromEnum<WeaponType>() ;
        }
        private static Potential getRandomPotential(){
            var potentialList = (
                strength: Util.getRandom(0,50),
                vitality: Util.getRandom(0,50),
                agility: Util.getRandom(0,50),
                dexterity: Util.getRandom(0,50),
                intelligence: Util.getRandom(0,50),
                mentality: Util.getRandom(0,50),
                strRatio: Util.getRandom(0.5,2),
                vitRatio: Util.getRandom(0.5,2),
                dexRatio: Util.getRandom(0.5,2),
                agiRatio: Util.getRandom(0.5,2),
                intRatio: Util.getRandom(0.5,2),
                menRatio: Util.getRandom(0.5,2)
            ) ;
            Potential potential = new Potential(potentialList);
            return potential;
        }
    }
}