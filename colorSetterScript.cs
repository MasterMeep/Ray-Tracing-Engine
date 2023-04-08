using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class colorSetterScript : MonoBehaviour
{
    public Color color;
    public Color emmisionColor;
    public float emmisionStrength;
    // Start is called before the first frame update
    void Start()
    {
        
    }

    // Update is called once per frame
    void Update()
    {
        GetComponent<Renderer>().material.SetColor("_EmissionColor", emmisionColor);
        GetComponent<Renderer>().material.SetFloat("_EmissionStrength", emmisionStrength);
        GetComponent<Renderer>().material.color = color;
    }
}
