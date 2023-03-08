namespace WeaponSystem {
    public class WeaponAttributes {
        public string name ;
        public double range ;
        public int weaponIndex ;
        public WeaponAttributes(int weaponIndex , string name, double range){
            this.weaponIndex = weaponIndex;
            this.name = name;
            this.range = range;
        }
    }
    public class WeaponAttributesList {
        public static List<WeaponAttributes> weaponAttributesList = new List<WeaponAttributes>(){
            new WeaponAttributes(1,"arrow",2),
            new WeaponAttributes(2,"axe",1),
            new WeaponAttributes(3,"tourch",2),
            new WeaponAttributes(4,"knife",1)
        };
        
        
        public static List<WeaponAttributes> getWeaponAttributesList(){
            return weaponAttributesList;
        }
        public static WeaponAttributes getWeaponAttributes (int weaponIndex){
            return weaponAttributesList[weaponIndex];
        }
    }
}