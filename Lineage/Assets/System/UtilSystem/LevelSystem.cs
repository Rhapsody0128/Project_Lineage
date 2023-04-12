using System;
using System.Collections;
using System.Collections.Generic;
namespace UtilSystem {
    public class LevelSystem {
        //等級
        public int level ;
        //經驗
        public int exp ;
        //經驗表
        public List<int> needExpToUpgrade = new List<int>{ 
          0,10,30,50
        };
        //素質等級比率
        public double potentialLevelRatio = 5;
        public LevelSystem (){
          this.exp = 0 ;
          this.level = 1 ;
        }
        public LevelSystem (int level){
          this.level = level ;
        }
        //獲得經驗值
        public void gainExp(int exp){
          if(this.level >= this.needExpToUpgrade.Count){
            return ;
          }
          this.exp += exp ;
          judgeCanUpgrade() ; 
        }
        //判斷升級
        private void judgeCanUpgrade(){
            if(this.level >= this.needExpToUpgrade.Count){
              return ;
            }
            var needExp = this.needExpToUpgrade[this.level] ;
            if(needExp < this.exp){
              this.exp -= needExp ; 
              this.level += 1;
              judgeCanUpgrade() ;
            }
        }
        //素質等級常數
        public double potentialLevelConstant {
            get {
                return level * potentialLevelRatio; ;
            }
        }
    }
}