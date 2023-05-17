using System;
using System.Collections;
using System.Collections.Generic;
using UtilSystem;
using PartySystem;
using HeroSystem;
using SoldierSystem;
using SkillSystem;
using WeaponSystem;
using Newtonsoft.Json.Linq;
using System.Linq;

namespace BattleSystem
{
    public class BattleParty
    {
        //隊伍物件
        public Party party;
        //戰場資訊
        public Battle battle;
        //是敵對
        Boolean isEnemy;
        //力量變化常數
        double strengthConst = 1;
        //敏捷變化常數
        double agilityConst = 1;
        //感知變化常數
        double perceptionConst = 1;
        //體質變化常數
        double vitalityConst = 1;
        //智慧變化常數
        double intelligenceConst = 1;
        //精神變化常數
        double mentalityConst = 1;
        //行動速度(回合變化)
        public double actionSpeed;
        //可行動表
        public List<KeyValuePair<string, double>> actionList =
            new List<KeyValuePair<string, double>> {
                new KeyValuePair<string, double> ( "attack",25 ),
                new KeyValuePair<string, double> ( "daze",5 ),
            };

        public BattleParty(Party party,Battle battle,Boolean isEnemy) {

            this.party = party;
            this.battle = battle;
            this.isEnemy = isEnemy;
            setActionChance();
        }

        private void setActionChance()
        {
            party.skillList.ForEach(skill =>
            {
                if (skill.bindWeapon == weapon?.weaponType || skill.bindWeapon == WeaponType.empty) {
                    var chance = skill.baseChance;
                    if (skill.skillType == poistionSkillType) {
                        chance *= 1.5;
                    };
                    actionList.Add(new KeyValuePair<string, double>(skill.id.ToString(), chance));
                }
            });
        }
        // 每回合的行動
        public void action() {
            var action = Util.getRandomChanceItem<string>(actionList);
            var target = searchEnemy();
            move(target);
            if (action.Key == "attack")
            {
                attack(target);
            }
            else if (action.Key == "daze")
            {
                daze();
            }
            else {
                Skill? skill = party.skillList.Find(skill =>
                {
                    return skill.id.ToString() == action.Key;
                });
                if (skill != null)
                {
                    skill.effect(this, target);
                }
                else {
                    daze();
                }
            }
        }
        //攻擊
        public void attack (BattleParty target) {
            Console.WriteLine(this.name + " attack " + target.name);
            if (judgeDodge(this,target))
            {
                return;
            }
            var damageBase = strength;
            var reduceBase = target.vitality;
            var damage = damageBase - (damageBase * (reduceBase / 200));
            target.beAttacked(damage);
        }
        //發呆
        public void daze()
        {
            Console.WriteLine(this.name + " daze");
        }
        //移動
        public void move(BattleParty target)
        {
            Console.WriteLine(this.name + " move to " + target.name);
        }
        //找尋目標敵人
        public BattleParty searchEnemy()
        {
            var random = Util.getRandom(0, emeny.Count);
            return emeny[random];
        }
        //受到攻擊時
        public void beAttacked(double damage)
        {

            int damagePoints = (int)Math.Round(damage);

            Console.WriteLine(this.name + " got " + damagePoints + " damage");

            List<Soldier> soldiers = party.soldiers;
            while (damagePoints > 0)
            {
                if (party.totalSoliderIsDisabled)
                {
                    Console.WriteLine(this.name + " all soliiders is disabled ");
                    return;
                }
                var random = Util.getRandom(0, soldiers.Count);
                Soldier soldier = soldiers[random];

                if (soldier.isDisabled)
                {
                    continue;
                }

                double avoidDeathRate = (20 + Util.getRandom(0, 20) + (vitality / 200) * 40) / 100;

                if (soldier.soldiersCount >= damagePoints)
                {
                    int deathCount = (int)Math.Round(damagePoints * (1 - avoidDeathRate));
                    int woundedCount = (int)Math.Round(damagePoints * avoidDeathRate);
                    soldier.deathSoldiersCount += deathCount;
                    soldier.woundedSoldiersCount += woundedCount;
                    damagePoints = 0;
                    Console.WriteLine(this.name + " 的 " + soldier.name + " death: " + deathCount + " and wounded: " + woundedCount);
                }
                else
                {
                    var remainSoldier = soldier.soldiersCount;
                    int deathCount = (int)Math.Round(remainSoldier * (1 - avoidDeathRate));
                    int woundedCount = (int)Math.Round(remainSoldier * avoidDeathRate);
                    soldier.deathSoldiersCount += deathCount;
                    soldier.woundedSoldiersCount += woundedCount;
                    damagePoints -= remainSoldier;
                    Console.WriteLine(this.name + " 的 " + soldier.name + " death: " + deathCount + " and wounded: " + woundedCount);
                }
            }
        }



        //判斷是否閃避
        public bool judgeDodge(BattleParty attacker, BattleParty defenser) {
            double dodgeRate = (defenser.agility - attacker.perception * 1.2) * 0.45;
            int random = Util.getRandom(0, 100);
            if (random < dodgeRate) {
                Console.WriteLine(defenser.name + " dodge from " + attacker.name);
                return true;
            }
            else {
                return false;
            }
        }


        //敵人
        public List<BattleParty> emeny {
            get{
                if (!isEnemy)
                {
                    return battle.enemyParties.Where(party=> !party.totalSoliderIsDisabled ).ToList();
                }
                else {
                    return battle.selfParties.Where(party => !party.totalSoliderIsDisabled).ToList();
                }
            }
        }
        //敵人主將
        public BattleParty emenyLeader
        {
            get
            {
                if (!isEnemy)
                {
                    return battle.enemyPartyLeader;
                }
                else
                {
                    return battle.selfPartyLeader;
                }
            }
        }


        //全部待命中士兵
        public int totalSoilderCount
        {
            get
            {
                return party.soldiers.Sum(soldiers => soldiers.soldiersCount);
            }
        }
        //全部受傷士兵
        public int totalWondedSoilderCount
        {
            get
            {
                return party.soldiers.Sum(soldiers => soldiers.woundedSoldiersCount);
            }
        }
        //全部無法行動士兵
        public bool totalSoliderIsDisabled
        {
            get
            {
                return party.soldiers.All(soldiers => soldiers.isDisabled);
            }
        }

        //武器
        public Weapon? weapon
        {
            get
            {
                return party.weapon;
            }
        }
        //陣形役
        public SkillType? poistionSkillType
        {
            get
            {
                return party.poistionSkillType;
            }
        }
        //名稱
        public string name
        {
            get
            {
                return party.name;
            }
        }
        //力量*力量變化常數
        public double strength {
            get{
                return party.strength * strengthConst;
            }
        }
        //敏捷*敏捷變化常數
        public double agility
        {
            get
            {
                return party.agility * agilityConst;
            }
        }
        //感知*靈巧變化常數
        public double perception
        {
            get
            {
                return party.perception * perceptionConst;
            }
        }
        //體質*體質變化常數
        public double vitality
        {
            get
            {
                return party.vitality * vitalityConst;
            }
        }
        //智慧*智慧變化常數
        public double intelligence
        {
            get
            {
                return party.intelligence * intelligenceConst;
            }
        }
        //精神*精神變化常數
        public double mentality
        {
            get
            {
                return party.mentality * mentalityConst;
            }
        }

    }
}