using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using RoleSystem;

public class CreateRoleBtn : MonoBehaviour
{

    public void CreateRole(){
        var role = RoleController.getRandomRole() ;
        Debug.Log(role.name) ;
    }
}
