using System;
using System.Collections;
using System.Collections.Generic;

namespace UtilSystem
{
    //男角色名稱
    public enum MaleHeroName { 約翰, 保羅, 喬治, 亞歷克斯, 馬克斯, 大衛, 丹尼爾, 馬克, 約瑟夫, 派屈克, 安德魯, 安東尼, 理查德, 查爾斯, 托馬斯, 威廉, 萊恩, 雅各布, 凱文, 邁克爾, 史蒂文, 彌敦, 愛德華, 布蘭登, 史考特, 班傑明, 埃里克, 約書亞, 菲利普, 布賴恩, 賈森, 格雷戈里, 撒迦 }
    //男角色姓氏
    public enum MaleHeroLastName { 貝克, 史密斯, 約翰遜, 威廉斯, 瓊斯, 布朗, 戴維斯, 米勒, 威爾遜, 摩爾, 泰勒, 安德森, 托馬斯, 傑克遜, 懷特, 哈里斯, 馬丁, 湯普森, 加西亞, 馬丁内斯, 羅賓遜, 克拉克, 羅德里格斯, 路易斯, 李, 沃克, 霍爾, 艾倫, 楊, 埃爾南德斯, 金, 賴特, 洛佩茲, 希爾, 斯科特, 格林, 亞當斯, 納爾遜, 卡特, 米歇爾, 佩雷斯, 羅伯茨, 特納, 菲利普斯, 坎貝爾, 帕克, 埃文斯, 愛德華茲, 柯林斯, 斯圖爾特, 桑切斯, 莫里斯, 羅傑斯, 里德, 庫克, 摩根, 貝爾, 墨菲, 貝利, 里維拉, 庫珀, 理查森, 考克斯, 霍華德, 華爾德, 托雷斯, 彼得森, 格雷, 拉米雷斯, 詹姆斯, 沃特森, 布魯克斯, 凱利, 桑德斯, 普萊斯, 班奈特, 伍德, 巴恩斯, 羅斯, 亨德森, 科爾曼, 傑金斯, 佩里, 鮑威爾, 亞歷山大, 羅素, 格里芬, 迪亞斯, 海斯, 邁爾斯, 福斯特, 哈密爾頓, 格雷厄姆, 沙利文, 華勒斯, 傅斯特, 哥倫茲, 布萊恩, 迪亞茲, 喬丹, 歐文斯, 雷諾斯, 費舍爾, 埃利斯, 加納斯 }
    //列出評比
    public enum RankType { E, D, C, B, A, S, SS, SSS }
    //六大素質
    public enum PotentialType { strength, vitality, agility, dexterity, intelligence, mentality }
    //六大武器種類
    public enum WeaponType { empty, sword, bow, shield, dagger, staff, scepter }
    //技能類型
    public enum SkillEffectType { attack, buff, debuff, heal, defend, leaderSkill }
    //戰鬥行動類型
    public enum ActionType { attack, daze, escape , confuse, skill }
    //外交狀態
    public enum Relations { self, allies, neutral, hostile, unknown }
}