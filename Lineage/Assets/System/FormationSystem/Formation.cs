using System;
using System.Collections;
using System.Collections.Generic;
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
    }
}