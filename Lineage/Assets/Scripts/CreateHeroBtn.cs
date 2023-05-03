using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;
using HeroSystem;
using TMPro;
using UtilSystem;

public class CreateHeroBtn : MonoBehaviour
{
    public TMP_Text  content; 
    public TMP_Text  title ; 
    public void CreateHero() {
        var hero = HeroController.getRandomHero() ;
        // GameObject obj = GameObject.Find("HeroInfo") ;
        // TMP_Text  text = obj.GetComponent<TMP_Text >();
        title.text = @$"{hero.name}·{hero.lastName}" ;
        content.text = $"力量 {hero.strength}  敏捷 {hero.agility}\n體質 {hero.vitality}  靈巧 {hero.dexterity}\n智慧 {hero.intelligence}  信仰 {hero.mentality}";
        GameObject sphere = GameObject.CreatePrimitive(PrimitiveType.Sphere);
        sphere.transform.position = new Vector3(Util.getRandom(0,400),Util.getRandom(0,200),0);
        sphere.transform.localScale  = new Vector3(40, 40, 40);
        
        Debug.Log(sphere) ;
    }
}
