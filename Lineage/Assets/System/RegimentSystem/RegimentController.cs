using BattalionSystem;
using System;
using System.Collections;
using System.Collections.Generic;
using UtilSystem;


namespace RegimentSystem
{
    public class RegimentController
    {
        //取得隨機軍團
        static public Regiment getRandomRegiment()
        {

            var battalions = new List<Battalion>();
            for (int i = 0; i < 5; i++)
            {
                battalions.Add(BattalionController.getRandomBattalion());
            }
            var regiment = new Regiment("隨機軍團", battalions);
            return regiment;
        }
    }
}