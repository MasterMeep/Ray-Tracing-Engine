using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public struct RayTracingMaterial {
    public Vector4 color;
    public float emissionStrength;
    public Vector4 emissionColor;

    //constructor
    public RayTracingMaterial(Vector4 color, float emissionStrength, Vector4 emissionColor) {
        this.color = color;
        this.emissionStrength = emissionStrength;
        this.emissionColor = emissionColor;
    }

};

public struct Sphere {
    public Vector3 position;
    public float radius;
    public RayTracingMaterial material;

    //constructor
    public Sphere(Vector3 position, float radius, RayTracingMaterial material) {
        this.position = position;
        this.radius = radius;
        this.material = material;
    }
};

[ExecuteAlways, ImageEffectAllowedInSceneView]
public class rayTracerScript : MonoBehaviour
{
    [SerializeField] bool useShaderInSceneView;
    [SerializeField] Shader rayTracingShader;
    [SerializeField] int maxBounceCount;
    [SerializeField] int raysPerPixel;
    Material rayTracingMaterial;
    List<Sphere> spheres;
    int numSpheres;

    // Start is called before the first frame update
    void OnRenderImage(RenderTexture source, RenderTexture target) {
        if(useShaderInSceneView) {
            if(rayTracingMaterial == null) {
                rayTracingMaterial = new Material(rayTracingShader);
            }
            if(spheres == null) {
                spheres = new List<Sphere>();

                GameObject[] allObjects = FindObjectsOfType<GameObject>();

            // Loop through all objects and add non-camera and non-light objects to the list
                foreach (GameObject obj in allObjects)
                {
                    // Check if the object is not a camera or light source
                    if (obj.GetComponent<Camera>() == null && obj.GetComponent<Light>() == null)
                    {
                        Renderer sphereRenderer = obj.GetComponent<Renderer>();
                        //if the object has an emission color and strength make variables called emissionColor and emissionStrength without useing the color setter script
                        Vector4 emissionColor = new Vector4(0, 0, 0, 0);
                        float emissionStrength = 0;
                        if (sphereRenderer.sharedMaterial.HasProperty("_EmissionColor") && sphereRenderer.sharedMaterial.HasProperty("_EmissionStrength")) {
                            emissionColor = sphereRenderer.sharedMaterial.GetColor("_EmissionColor");
                            emissionStrength = sphereRenderer.sharedMaterial.GetFloat("_EmissionStrength");
                            Debug.Log("Emission Strength: " + emissionStrength);
                        }
                        RayTracingMaterial material = new RayTracingMaterial(sphereRenderer.sharedMaterial.color, emissionStrength, emissionColor);
                        Sphere sphere = new Sphere(obj.transform.position, obj.transform.localScale.x/2, material);
                        spheres.Add(sphere);
                    }
                }
            }
        numSpheres = spheres.Count;
            UpdateCameraParams();

            Graphics.Blit(null, target, rayTracingMaterial);
        } else {
            Graphics.Blit(source, target);
        }
    }
    
    void Start() {
        
    }

    // Update is called once per frame
    void UpdateCameraParams()
    {
        if (rayTracingMaterial == null || Camera.main == null || spheres == null) {
            return;
        }
        float planeHeight = Camera.main.nearClipPlane * Mathf.Tan(0.5f * Camera.main.fieldOfView * Mathf.Deg2Rad)*2;
        float planeWidth = planeHeight * Camera.main.aspect;

        //make a buffer from the spheres array
        ComputeBuffer spheresBuffer = new ComputeBuffer(numSpheres, sizeof(float) * 13);
        spheresBuffer.SetData(spheres.ToArray());
        rayTracingMaterial.SetVector("ViewParams", new Vector3(planeWidth, planeHeight, Camera.main.nearClipPlane));
        rayTracingMaterial.SetMatrix("CamLocalToWorldMatrix", Camera.current.transform.localToWorldMatrix);
        rayTracingMaterial.SetInt("SphereCount", numSpheres);
        rayTracingMaterial.SetInt("MaxBounceCount", maxBounceCount);
        rayTracingMaterial.SetInt("NumRaysPerPixel", raysPerPixel);
        rayTracingMaterial.SetBuffer("Spheres", spheresBuffer);

    }
}
