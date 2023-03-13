using UtilSystem;
using SkillSystem;

namespace WeaponSystem {
    public class Weapon {
        private Guid id ;
        public string name ;
        public WeaponType weaponType ;
        public Potential potential ;
        public Boolean equipState ;
        
        public List<Skill>? skill ;
        public Weapon(
            string name,
            Potential potential,
            WeaponType weaponType,
            List<Skill>? skill
        ){
            this.id = Guid.NewGuid();
            this.name = name;
            this.potential = potential;
            this.weaponType = weaponType;
            this.equipState = false;
            this.skill = skill;
        }
        public void changeEquipState(Boolean value){
            this.equipState = value;
        }
    }
}