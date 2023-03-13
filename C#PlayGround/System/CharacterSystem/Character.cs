using UtilSystem;
using WeaponSystem;
using SkillSystem;

namespace CharacterSystem {
    public class Character {
        private Guid id ;
        public string name ;
        public string lastName ;
        public Potential potential ;
        public Weapon? holdingWeapon ;
        public List<Skill>? skill ;
        
        public Character(string name,string lastName,Potential potential,List<Skill>? skill){
            this.name = name;
            this.lastName = lastName;
            this.id = Guid.NewGuid();
            this.potential = potential;
            this.skill = skill ;
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