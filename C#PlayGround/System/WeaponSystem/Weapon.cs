using UtilSystem;

namespace WeaponSystem {
    public class Weapon {
        private Guid id ;
        public string name ;
        public WeaponAttributes weaponAttributes ;
        public Ability ability;
        public Boolean equipState;
        public Weapon(string name,Ability ability,WeaponAttributes weaponAttributes){
            this.name = name;
            this.id = Guid.NewGuid();
            this.ability = ability;
            this.weaponAttributes = weaponAttributes;
            this.equipState = false;
        }
        public void changeEquipState(Boolean value){
            this.equipState = value;
        }
    }
}