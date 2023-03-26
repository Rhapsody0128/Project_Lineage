using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;
using RoleSystem;
using TMPro;
using UtilSystem;

public class CreateRoleBtn : MonoBehaviour
{
    public TMP_Text  content; 
    public TMP_Text  title ; 
    public void CreateRole() {
        var role = RoleController.getRandomRole() ;
        // GameObject obj = GameObject.Find("RoleInfo") ;
        // TMP_Text  text = obj.GetComponent<TMP_Text >();
        title.text = @$"{role.name}·{role.lastName}" ;
        content.text = $"力量 {role.strength}  敏捷 {role.agility}\n體質 {role.vitality}  靈巧 {role.dexterity}\n智慧 {role.intelligence}  信仰 {role.mentality}";
        GameObject sphere = GameObject.CreatePrimitive(PrimitiveType.Sphere);
        sphere.transform.position = new Vector3(Util.getRandom(0,400),Util.getRandom(0,200),0);
        sphere.transform.localScale  = new Vector3(40, 40, 40);
        
        Debug.Log(sphere) ;
    }
}
