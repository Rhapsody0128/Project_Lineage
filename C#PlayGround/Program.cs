using RoleSystem;
using WeaponSystem;
using TroopSystem;
using UtilSystem;


public class Program {
    static void Main(string[] args) {
        // RoleTryUpgrade() ;
        TroopTry() ;
        // WeaponTry(); 


        
        // System.Console.WriteLine() ;
    }
    static public void TroopTry(){
        var troop = TroopControlle.getRandomTroop(); 
        System.Console.WriteLine("名稱:{0},行軍速度{1}",troop.name,123) ;
    }
    static public void RoleTryUpgrade(){
        Role person = RoleController.getRandomRole();

        System.Console.WriteLine("角色,名字:{0},等級{1},力量:{2},原始力量:{3},力量成長比:{4}",person.name,person.levelSystem.level,person.strength,person.potential.strength,person.potential.strRatio);
        System.Console.WriteLine("角色升級後-------------");
        person.levelSystem.gainExp(200) ; 
        System.Console.WriteLine("角色,名字:{0},等級:{1},力量:{2},原始力量:{3},力量成長比:{4}",person.name,person.levelSystem.level,person.strength,person.potential.strength,person.potential.strRatio);
        var weapon = WeaponController.getRandomWeapon() ;
        person.equipWeapon(weapon);
        System.Console.WriteLine("穿武器後---------");
        System.Console.WriteLine("角色,名字:{0},等級:{1},力量:{2},原始力量:{3},力量成長比:{4}",person.name,person.levelSystem.level,person.strength,person.potential.strength,person.potential.strRatio);
        System.Console.WriteLine("武器,名字:{0},等級:{2},力量:{1},力量成長比:{3}",weapon.name,weapon.strength,weapon.levelSystem.level,weapon.potential.strRatio);
        weapon.levelSystem.gainExp(200);
        System.Console.WriteLine("武器升級後--------");
        System.Console.WriteLine("角色,名字:{0},等級:{1},力量:{2},原始力量:{3},力量成長比:{4}",person.name,person.levelSystem.level,person.strength,person.potential.strength,person.potential.strRatio);
        System.Console.WriteLine("武器,名字:{0},等級:{2},力量:{1},力量成長比:{3}",weapon.name,weapon.strength,weapon.levelSystem.level,weapon.potential.strRatio);
        
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
        System.Console.WriteLine(weapon.name);
        System.Console.WriteLine(weapon.weaponType);
        System.Console.WriteLine("等級:{0} exp:{1}",level,exp);
        if(weapon.skill != null){
            System.Console.WriteLine(weapon.skill[0].name);
        }else{
            System.Console.WriteLine("no Skill");
        }
    }
}