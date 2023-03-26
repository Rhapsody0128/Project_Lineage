using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;
using TMPro;

public class ToolTip : MonoBehaviour
{
    public TMP_Text content ; 
    public TMP_Text title ;
    public GameObject ToolTipObject ;
    // Start is called before the first frame update
    void Start()
    {
        content.text = "content"; 
        title.text = "title";
        ToolTipObject.SetActive(false) ;
        
    }

    // Update is called once per frame
    void Update()
    {

    }
    void OnMouseOver () {
        ToolTipObject.SetActive(true) ;
    }
    void OnMouseExit() {
        ToolTipObject.SetActive(false) ;
    }
}
