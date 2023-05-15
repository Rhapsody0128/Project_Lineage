using System;
using System.Collections;
using System.Collections.Generic;
using System.Numerics;
using UtilSystem;
using WeaponSystem;
using PartySystem;


namespace FormationSystem
{
    public class FormationCell
    {
        //座標位置
        public Vector2 position;
        //陣形役(攻擊位,防禦位等等)
        public SkillType poistionSkillType;
        //武器
        public Weapon weapon;

        public FormationCell(
            Vector2 position,
            SkillType poistionSkillType
        )
        {
            this.position = position;
            this.poistionSkillType = poistionSkillType;
            weapon = WeaponController.getDefaultWeapon();
        }
        public void setWeapon(Weapon weapon)
        {
            this.weapon = weapon;
        }
    }
}