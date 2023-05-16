using System;
using System.Collections;
using System.Collections.Generic;
using UtilSystem;
using PartySystem;
using HeroSystem;
using SoldierSystem;
using SkillSystem;
using WeaponSystem;
using static System.Net.Mime.MediaTypeNames;
using Newtonsoft.Json.Linq;

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
            party.skillList.ForEach(skill =>
            {
                actionList.Add(new KeyValuePair<string, double>(skill.id.ToString(), skill.baseChance ));
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
            target.beAttacked(this, strength);
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
        public void beAttacked(BattleParty attacker,double damage) {
            if (judgeDodge(attacker,this)) {
                return;
            }
            int damagePoints = (int)Math.Round(damage - (damage * (vitality / 200)));
            Console.WriteLine(attacker.name + " damage to " + this.name +  " about " + result + " points ");



            int death = damagePoints;
            double avoidDeathRate = 20 + Util.getRandom(0, 20) + (vitality / 200) * 40;
            List<int> deathList = new List<int>();
            for (int i = 0;i< this.party.soldiers.Count; i++)
            {
                var deathCount = Util.getRandom(0, death);
                deathList.Add(deathCount);
            }
            Random rand = new Random();
            deathList = deathList.OrderBy(e => rand.Next()).ToList();
            for (int i = 0; i < this.party.soldiers.Count; i++) {
                var solider = this.party.soldiers[i];
                var deathCount = deathList[i];
                solider.lossSoldiers(deathCount, avoidDeathRate);
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
                    return battle.enemyParties;
                }
                else {
                    return battle.selfParties;
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



        //武器
        public Weapon? weapon
        {
            get
            {
                return party.weapon;
            }
        }
        //
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