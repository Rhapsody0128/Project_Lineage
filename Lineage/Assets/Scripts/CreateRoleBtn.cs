using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;
using RoleSystem;
using TMPro;

public class CreateRoleBtn : MonoBehaviour
{
    public TMP_Text  textField ; 
    public void CreateRole() {
        var role = RoleController.getRandomRole() ;
        // GameObject obj = GameObject.Find("RoleInfo") ;
        // TMP_Text  text = obj.GetComponent<TMP_Text >();
        string str = @$"姓名 {role.name}·{role.lastName}
力量 {role.strength}
敏捷 {role.agility}
體質 {role.vitality}
靈巧 {role.dexterity}
智慧 {role.intelligence}
信仰 {role.mentality}";
        textField.text = str ; 
    }
}
