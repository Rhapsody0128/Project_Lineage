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
        person.equipWeapon(weapon);
        person.unEquipWeapon();
        person2.equipWeapon(weapon);
        if(person.holdingWeapon is not null){
            Console.WriteLine(person.holdingWeapon.name);

        }
        if(person2.holdingWeapon is not null){
            Console.WriteLine(person2.holdingWeapon.name);
        }


        // Console.WriteLine()
    }
}