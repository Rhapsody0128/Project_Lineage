using UtilSystem;

namespace WeaponSystem {
    public class Weapon {
        private Guid id ;
        public string name ;
        public WeaponAttributes weaponAttributes ;
        public Potential potential;
        public Boolean equipState;
        public Weapon(string name,Potential potential,WeaponAttributes weaponAttributes){
            this.name = name;
            this.id = Guid.NewGuid();
            this.potential = potential;
            this.weaponAttributes = weaponAttributes;
            this.equipState = false;
        }
        public void changeEquipState(Boolean value){
            this.equipState = value;
        }
    }
}