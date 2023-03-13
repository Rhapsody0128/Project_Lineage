using CharacterSystem;
using WeaponSystem;
using UtilSystem;


public class Program {
    static void Main(string[] args) {
        Character person = CharacterController.getRandomCharacter();
        Character person2 = CharacterController.getRandomCharacter();
        Character child = CharacterController.bornChild(person2,person);
        Weapon weapon = WeaponController.getRandomWeapon();

        // person.unEquipWeapon();
        // person.equipWeapon(weapon);
        // person.unEquipWeapon();
        // person2.equipWeapon(weapon);
        // Console.WriteLine(weapon.name);
        // Console.WriteLine(weapon.weaponType);
        // if(weapon.skill != null){
        //     Console.WriteLine(weapon.skill[0].name);
        // }else{
        //     Console.WriteLine("no Skill");
        // }


        var rankType = Util.getRandomFromEnum<RankType>() ;

        Console.WriteLine(rankType) ;


        
        // Console.WriteLine() ;
    }
}