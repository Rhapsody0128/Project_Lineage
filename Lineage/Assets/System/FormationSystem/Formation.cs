using System;
using System.Collections;
using System.Collections.Generic;
using System.Numerics;
using UtilSystem;


namespace FormationSystem
{
    public class Formation
    {
        //陣行名稱
        public string name;
        //List
        public List<FormationCell> formationCellList;

        public Formation(
            string name,
            List<FormationCell> formationCells
        )
        {
            this.name = name;
            this.formationCellList = formationCells;
        }
        public FormationCell? getFormationCell (Vector2 position)
        {
            var formationCell = formationCellList.Find((FormationCell formationCell) =>
            {
                return formationCell.position.X == position.X && formationCell.position.Y == position.Y;
            });
            return formationCell;
        }
    }
}