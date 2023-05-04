using System;
using System.Collections;
using System.Collections.Generic;
using System.Numerics;
using UtilSystem;


namespace FormationSystem
{
    public class FormationCell
    {
        public Vector2 position;
        //移動速度常數
        public SkillEffectType skillEffectType;

        public FormationCell(
            Vector2 position,
            SkillEffectType skillEffectType
        )
        {
            this.position = position;
            this.skillEffectType = skillEffectType;
        }
    }
}