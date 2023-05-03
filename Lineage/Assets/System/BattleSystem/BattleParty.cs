using System;
using System.Collections;
using System.Collections.Generic;
using UtilSystem;
using PartySystem;
using HeroSystem;
using SoldierSystem;
using SkillSystem;
using System.Reflection;

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
        //靈巧變化常數
        double dexterityConst = 1;
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
            Console.WriteLine("{0}-速度{1}=原始速度{2}*速度常數{3}", party.name, agility,party.agility, agilityConst);
            //Console.WriteLine("{0}-速度{1}", party.name, actionSpeed);
        }
        //
        public double getActionChance (string actionType) {
            return 0;
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
        //靈巧*靈巧變化常數
        public double dexterity
        {
            get
            {
                return party.dexterity * dexterityConst;
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