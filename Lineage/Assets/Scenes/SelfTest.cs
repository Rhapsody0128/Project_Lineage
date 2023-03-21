using System.Diagnostics;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using RoleSystem;
using WeaponSystem;
using TroopSystem;
using UtilSystem;

public class SelfTest : MonoBehaviour
{
    // Start is called before the first frame update
    void Start()
    {
        TroopTry() ;
    }

    // Update is called once per frame
    void Update()
    {

    }
    
    static public void TroopTry(){
        var troop = TroopController.getRandomTroop(); 
        UnityEngine.Debug.LogFormat("名稱:{0},行軍速度{1}",troop.name,123) ;
    }
    static public void RoleTryUpgrade(){
        Role person = RoleController.getRandomRole();

        UnityEngine.Debug.LogFormat("角色,名字:{0},等級{1},力量:{2},原始力量:{3},力量成長比:{4}",person.name,person.levelSystem.level,person.strength,person.potential.strength,person.potential.strRatio);
        UnityEngine.Debug.Log("角色升級後-------------");
        person.levelSystem.gainExp(200) ; 
        UnityEngine.Debug.LogFormat("角色,名字:{0},等級:{1},力量:{2},原始力量:{3},力量成長比:{4}",person.name,person.levelSystem.level,person.strength,person.potential.strength,person.potential.strRatio);
        var weapon = WeaponController.getRandomWeapon() ;
        person.equipWeapon(weapon);
        UnityEngine.Debug.Log("穿武器後---------");
        UnityEngine.Debug.LogFormat("角色,名字:{0},等級:{1},力量:{2},原始力量:{3},力量成長比:{4}",person.name,person.levelSystem.level,person.strength,person.potential.strength,person.potential.strRatio);
        UnityEngine.Debug.LogFormat("武器,名字:{0},等級:{2},力量:{1},力量成長比:{3}",weapon.name,weapon.strength,weapon.levelSystem.level,weapon.potential.strRatio);
        weapon.levelSystem.gainExp(200);
        UnityEngine.Debug.Log("武器升級後--------");
        UnityEngine.Debug.LogFormat("角色,名字:{0},等級:{1},力量:{2},原始力量:{3},力量成長比:{4}",person.name,person.levelSystem.level,person.strength,person.potential.strength,person.potential.strRatio);
        UnityEngine.Debug.LogFormat("武器,名字:{0},等級:{2},力量:{1},力量成長比:{3}",weapon.name,weapon.strength,weapon.levelSystem.level,weapon.potential.strRatio);
        
        Role person2 = RoleController.getRandomRole();
        Role child = RoleController.bornChild(person2,person);
    }
    static public void WeaponTry(){
        Role person = RoleController.getRandomRole();
        Role person2 = RoleController.getRandomRole();
        Weapon weapon = WeaponController.getRandomWeapon();
        var level = weapon.levelSystem.level ;
        var exp = weapon.levelSystem.exp ;

        person.equipWeapon(weapon);
        person.unEquipWeapon();
        person2.equipWeapon(weapon);
        UnityEngine.Debug.Log(weapon.name);
        UnityEngine.Debug.Log(weapon.weaponType);
        UnityEngine.Debug.LogFormat("等級:{0} exp:{1}",level,exp);
        if(weapon.skill != null){
            UnityEngine.Debug.Log(weapon.skill[0].name);
        }else{
            UnityEngine.Debug.Log("no Skill");
        }
    }
}
