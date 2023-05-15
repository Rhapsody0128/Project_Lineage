using System;
using System.Collections;
using System.Collections.Generic;
using System.Numerics;
using UtilSystem;



// 7 6 5 4 3 2 1 0
//               1
//               2
//               3
// ----------------
// 3
// 2     我方
// 1
// 0 1 2 3 4 5 6 7
namespace FormationSystem
{
    public class FormationController
    {
        private static List<Formation> formationList = new List<Formation>(){
            new Formation(
                "方陣",
                new List<FormationCell>{
                    new FormationCell(new Vector2(1,1),SkillType.attack),
                    new FormationCell(new Vector2(1,2),SkillType.defend),
                    new FormationCell(new Vector2(2,1),SkillType.buff),
                    new FormationCell(new Vector2(2,2),SkillType.debuff),
                    new FormationCell(new Vector2(3,1),SkillType.heal),
                    new FormationCell(new Vector2(3,2),SkillType.attack),
                }
            ),
        };
        //取得所有陣行
        public static List<Formation> getFormationList()
        {
            return formationList;
        }
        //取得陣行byIndex
        public static Formation getFormation(int formationIndex)
        {
            return formationList[formationIndex];
        }
        //取得隨機陣行
        public static Formation getRandomFormation()
        {
            var formationIndex = Util.getRandom(0, formationList.Count);
            Formation formation = FormationController.getFormation(formationIndex);
            return formation;
        }
    }
}