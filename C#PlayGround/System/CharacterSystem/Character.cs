using UtilSystem;
using WeaponSystem;

namespace CharacterSystem {
    public class Character {
        private Guid id ;
        public string name ;
        public Potential potential;
        public Weapon? holdingWeapon;
        
        public Character(string name,Potential potential){
            this.name = name;
            this.id = Guid.NewGuid();
            this.potential = potential;
        }       
        public void equipWeapon(Weapon weapon){

            if(weapon.equipState is true){
                throw new InvalidOperationException("weapon has been equiped");
            }
            if(this.holdingWeapon is not null){
                this.holdingWeapon.changeEquipState(false);
            }
            this.holdingWeapon = weapon;
            this.holdingWeapon.changeEquipState(true);

        }
        public void unEquipWeapon(){
            if(this.holdingWeapon is null){
                throw new InvalidOperationException("no weapon to unEquip");
            }
            this.holdingWeapon.changeEquipState(false);
            this.holdingWeapon = null;

        }
    }
}