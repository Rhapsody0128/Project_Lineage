using CharacterSystem;
using WeaponSystem;
using TroopSystem;
using UtilSystem;


public class Program {
    static void Main(string[] args) {
        // CharacterTryUpgrade() ;
        TroopTry() ;
        // WeaponTry(); 


        
        // Console.WriteLine() ;
    }
    static public void TroopTry(){
        var troop = TroopController.getRandomTroop(); 
        Console.WriteLine("名稱:{0},行軍速度{1}",troop.name,troop.moveSpeed) ;
    }
    static public void CharacterTryUpgrade(){
        Character person = CharacterController.getRandomCharacter();

        Console.WriteLine("角色,名字:{0},等級{1},力量:{2},原始力量:{3},力量成長比:{4}",person.name,person.levelSystem.level,person.strength,person.potential.strength,person.potential.strRatio);
        Console.WriteLine("角色升級後-------------");
        person.levelSystem.gainExp(200) ; 
        Console.WriteLine("角色,名字:{0},等級:{1},力量:{2},原始力量:{3},力量成長比:{4}",person.name,person.levelSystem.level,person.strength,person.potential.strength,person.potential.strRatio);
        var weapon = WeaponController.getRandomWeapon() ;
        person.equipWeapon(weapon);
        Console.WriteLine("穿武器後---------");
        Console.WriteLine("角色,名字:{0},等級:{1},力量:{2},原始力量:{3},力量成長比:{4}",person.name,person.levelSystem.level,person.strength,person.potential.strength,person.potential.strRatio);
        Console.WriteLine("武器,名字:{0},等級:{2},力量:{1},力量成長比:{3}",weapon.name,weapon.strength,weapon.levelSystem.level,weapon.potential.strRatio);
        weapon.levelSystem.gainExp(200);
        Console.WriteLine("武器升級後--------");
        Console.WriteLine("角色,名字:{0},等級:{1},力量:{2},原始力量:{3},力量成長比:{4}",person.name,person.levelSystem.level,person.strength,person.potential.strength,person.potential.strRatio);
        Console.WriteLine("武器,名字:{0},等級:{2},力量:{1},力量成長比:{3}",weapon.name,weapon.strength,weapon.levelSystem.level,weapon.potential.strRatio);
        
        Character person2 = CharacterController.getRandomCharacter();
        Character child = CharacterController.bornChild(person2,person);
    }
    static public void WeaponTry(){
        Character person = CharacterController.getRandomCharacter();
        Character person2 = CharacterController.getRandomCharacter();
        Weapon weapon = WeaponController.getRandomWeapon();
        var level = weapon.levelSystem.level ;
        var exp = weapon.levelSystem.exp ;

        person.equipWeapon(weapon);
        person.unEquipWeapon();
        person2.equipWeapon(weapon);
        Console.WriteLine(weapon.name);
        Console.WriteLine(weapon.weaponType);
        Console.WriteLine("等級:{0} exp:{1}",level,exp);
        if(weapon.skill != null){
            Console.WriteLine(weapon.skill[0].name);
        }else{
            Console.WriteLine("no Skill");
        }
    }
}