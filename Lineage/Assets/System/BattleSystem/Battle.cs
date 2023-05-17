using System;
using System.Collections;
using System.Collections.Generic;
using UtilSystem;
using TroopSystem;
using PartySystem;

namespace BattleSystem
{
    public class Battle
    {
        //我方全隊伍
        public List<BattleParty> selfParties;
        //我方隊長
        public BattleParty selfPartyLeader;
        //敵方全隊伍
        public List<BattleParty> enemyParties;
        //敵方隊長
        public BattleParty enemyPartyLeader;
        //總回合數
        private int totalRound = 10;
        //回合數
        private int round = 0;

        public Battle(Troop selfTroop, Troop enemyTroop) {
            this.selfParties = attachBattleParams(false,selfTroop.parties);
            this.selfPartyLeader = attachBattleParams(false,selfTroop.partyLeader);
            this.enemyParties = attachBattleParams(true,enemyTroop.parties);
            this.enemyPartyLeader = attachBattleParams(true,enemyTroop.partyLeader);
        }

        //給party附加戰鬥相關參數
        private BattleParty attachBattleParams(Boolean isEmemy,Party party) {
            return new BattleParty(party,this,isEmemy);
        }
        //給parties附加戰鬥相關參數
        private List<BattleParty> attachBattleParams(Boolean isEmemy, List<Party> parties)
        {
            List<BattleParty> battleParties = new List<BattleParty>();
            parties.ForEach(party => {
                var battleParty = new BattleParty(party, this, isEmemy);
                battleParties.Add(battleParty);
            });
            return battleParties;
        }
        //行動順序
        public List<BattleParty> actionOrder {
            get {
                List<BattleParty> battleParties = new List<BattleParty>();
                selfParties.ForEach(party => {
                    if (!party.totalSoliderIsDisabled) {
                        battleParties.Add(party);
                    }
                });
                enemyParties.ForEach(party => {
                    if (!party.totalSoliderIsDisabled)
                    {
                        battleParties.Add(party);
                    }
                });
                battleParties.Sort((x, y) =>
                    y.actionSpeed.CompareTo(x.actionSpeed)
                );
                return battleParties;
            }
        }

        //開始戰鬥
        public void start()
        {
            initBattle();
            while (round < totalRound) {
                if (judgeOver())
                {
                    return;
                }
                roundStart();
                roundProgress();
                roundEnd();
            }
        }
        //初始化battle
        private void initBattle()
        {
            Console.WriteLine("戰鬥開始");
        }
        // 回合開始
        private void roundStart()
        {
            Console.WriteLine("------------第{0}回------------", round + 1);
        }
        //回合進行
        public void roundProgress() {
            actionOrder.ForEach(party =>
            {
                if (judgeOver())
                {
                    return;
                }
                if (!party.totalSoliderIsDisabled) {
                    party.action();
                }
            });
            
        }
        // 回合結束
        private void roundEnd()
        {
            Console.WriteLine("回合結束");
            round++;
        }
        private bool judgeOver() {
            var selfLeaderDisabled = selfPartyLeader.totalSoliderIsDisabled;
            if (selfLeaderDisabled)
            {
                Console.WriteLine("我方總大將" + selfPartyLeader.name + "敗退");
                return selfLeaderDisabled;
            }
            var enemyLeaderDisabled = enemyPartyLeader.totalSoliderIsDisabled;
            if (enemyLeaderDisabled)
            {
                Console.WriteLine("敵方總大將" + enemyPartyLeader.name + "敗退");
                return enemyLeaderDisabled;
            }
            return false;
        }
    }
}