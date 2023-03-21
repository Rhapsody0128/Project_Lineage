using System.Collections.Generic;
namespace UtilSystem {
    public class LevelSystem {

        public int level ;
        public int exp ;
        
        public List<int> needExpToUpgrade = new List<int>{ 
          0,10,30,50
        };
        public LevelSystem (){
          this.exp = 0 ;
          this.level = 1 ;
        }
        public LevelSystem (int level,int exp){
          this.level = level ;
          this.exp = exp ;
          judgeCanUpgrade() ;
        }
        public void gainExp(int exp){
          if(this.level >= this.needExpToUpgrade.Count){
            return ;
          }
          this.exp =+ exp ;
          judgeCanUpgrade() ; 
        }
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
    }
}