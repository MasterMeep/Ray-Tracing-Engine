Shader "Unlit/raytracerShader"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog
            

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }





            struct Ray {
                float3 origin;
                float3 direction;
            };
            struct RayTracingMaterial {
                float4 color;
                float emissionStrength;
                float4 emissionColor;

            };

            struct Sphere {
                float3 position;
                float radius;
                RayTracingMaterial material;
            };

            struct HitInfo {
                bool didHit;
                float distance;
                float3 hitPoint;
                float3 normal;
                RayTracingMaterial material;
            };

            float3 ViewParams;
            float4x4 CamLocalToWorldMatrix;
            StructuredBuffer<Sphere> Spheres;
            int SphereCount;
            int MaxBounceCount;
            int NumRaysPerPixel;



            float RandomValue(inout uint state) {
                state = state * 747796405 + 2891336453;
                uint result  = ((state >> ((state >> 28) + 4)) ^ state) * 277803737;
                result = (result >> 22) ^ result;
                return result/4294967295.0;
            }
            
            float RandomValueWithNormalDistribution(inout uint state) {
                float theta = 2*3.1415926*RandomValue(state);
                float rho = sqrt(-2 * log(RandomValue(state)));
                return rho * cos(theta);
            }

            float3 RandomDirection(inout uint state) {
                float x = RandomValueWithNormalDistribution(state);
                float y = RandomValueWithNormalDistribution(state);
                float z = RandomValueWithNormalDistribution(state);
                return normalize(float3(x, y, z));
            }

            float3 RandomHemisphere(float3 normal, inout uint state) {
                float3 randomDirection = RandomDirection(state);
                return randomDirection * sign(dot(normal, randomDirection));
            }

            HitInfo RaySphereIntersection(float3 rayOrigin, float3 rayDirection, float3 sphereCenter, float sphereRadius)
            {
                HitInfo hitInfo = (HitInfo)0;

                // Calculate the vector between the ray origin and sphere center
                float3 rayToSphere = sphereCenter - rayOrigin;

                // Calculate the projection of rayToSphere onto the ray direction
                float projection = dot(rayToSphere, rayDirection);

                float3 closestPoint = rayOrigin + projection * rayDirection;
                float distance = length(closestPoint - sphereCenter);

                // If the projection is negative, the sphere is behind the ray
                if (projection < 0.0f || distance > sphereRadius)
                    hitInfo.didHit = false;
                else {
                    hitInfo.didHit = true;
                    hitInfo.distance = projection - sqrt(sphereRadius * sphereRadius - distance * distance);
                    hitInfo.hitPoint = rayOrigin + rayDirection * hitInfo.distance;
                    hitInfo.normal = normalize(hitInfo.hitPoint - sphereCenter);
                }
                // If we get here, there is an intersection
                return hitInfo;
            }

            HitInfo CheckAllSphereIntersections(Ray ray) {
                HitInfo hitInfo = (HitInfo)0;

                hitInfo.distance = 100000;

                
                for(int i = 0; i < SphereCount; i++) {
                    Sphere sphere = Spheres[i];
                    HitInfo sphereHitInfo = RaySphereIntersection(ray.origin, ray.direction, sphere.position, sphere.radius);
                    if(sphereHitInfo.didHit && sphereHitInfo.distance < hitInfo.distance) {
                        hitInfo = sphereHitInfo;
                        hitInfo.material = sphere.material;
                    }
                }

                return hitInfo;
            }

            float3 getEnvironmentLight(Ray ray) {
                float skyGradientT = pow(smoothstep(0, 0.4, ray.direction.y), 0.35);
                float3 skyGradient = lerp(float3(0.5, 0.6, 0.7), float3(0.1, 0.1, 0.1), skyGradientT);
                float sun = pow(max(0, dot(ray.direction, normalize(float3(0.5, 1, 0.5)))), 100);
                return skyGradient + sun * float3(1, 0.8, 0.6);
            }

            float3 Trace(Ray ray, inout uint state) {
                float3 incomingLight = 0;
                float3 rayColor = 1;

                for(int i = 0; i <= MaxBounceCount; i++) {
                    HitInfo hitInfo = CheckAllSphereIntersections(ray);
                    if(!hitInfo.didHit) {
                        //incomingLight = getEnvironmentLight(ray);
                        break;
                    }

                    RayTracingMaterial material = hitInfo.material;
                    incomingLight += material.emissionColor * material.emissionStrength * rayColor;

                    rayColor *= material.color;

                    ray.origin = hitInfo.hitPoint;
                    float3 normal = hitInfo.normal;
                    ray.direction = RandomHemisphere(normal, state);

                }

                return incomingLight;
            }

            int frame = 0;

            fixed4 frag (v2f i) : SV_Target
            {
                

                uint2 numPixels = _ScreenParams.xy;
                uint2 pixelCoord = i.uv * numPixels;
                uint rngState = pixelCoord.y * numPixels.x + pixelCoord.x + frame*8782459;

                float3 localPoint = float3(i.uv - 0.5, 1) * ViewParams;
                float3 worldPoint = mul(CamLocalToWorldMatrix, float4(localPoint, 1));

                Ray ray;
                ray.origin = _WorldSpaceCameraPos;
                ray.direction = normalize(worldPoint - ray.origin);

                float3 totalIncomingLight = 0;

                for(int index = 0; index < NumRaysPerPixel; index++) {
                    totalIncomingLight += Trace(ray, rngState);
                }

                float4 color = float4(totalIncomingLight/NumRaysPerPixel, 1);
                frame++;
                return color;

            }

            ENDCG
        }
    }
}
