using UtilSystem ;

namespace SkillSystem {
    public class Skill {
        public string name ;
        public int range ;
        public int scope ;
        public PotentialType effectBasedOn ;
        public Boolean effectTargetEnemy ;
        public WeaponType? BindWeapon  ; 
        
        public Skill(
            string name,
            int range,
            int scope,
            PotentialType effectBasedOn,
            Boolean effectTargetEnemy,
            WeaponType? BindWeapon
        ){
            this.name = name;
            this.range = range;
            this.scope = scope;
            this.effectBasedOn = effectBasedOn;
            this.effectTargetEnemy = effectTargetEnemy;
            this.BindWeapon = BindWeapon;
        }

    }
}