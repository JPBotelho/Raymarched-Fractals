Shader "Hidden/RaymarchGeneric"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
	}
	SubShader
	{
		Cull Off ZWrite Off ZTest Always

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma target 4.0

			#include "UnityCG.cginc"
			#include "DistanceFunc.cginc"
			
			uniform sampler2D _CameraDepthTexture;
			uniform sampler2D _MainTex;
			uniform float4 _MainTex_TexelSize;

			uniform float4x4 _CameraInvViewMatrix;
			uniform float4x4 _FrustumCornersES;
			uniform float4 _CameraWS;

			uniform float3 _LightDir;
			uniform float _DrawDistance;

			uniform float4 _Color1;
			uniform float4 _Color2;
			uniform float4 _Color3;
			uniform float4 _Color4;
			uniform float4 _Color5;

			struct appdata
			{
				// Remember, the z value here contains the index of _FrustumCornersES to use
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float4 pos : SV_POSITION;
				float2 uv : TEXCOORD0;
				float3 ray : TEXCOORD1;
			};

			v2f vert (appdata v)
			{
				v2f o;
				
				// Index passed via custom blit function in RaymarchGeneric.cs
				half index = v.vertex.z;
				v.vertex.z = 0.1;
				
				o.pos = UnityObjectToClipPos(v.vertex);
				o.uv = v.uv.xy;
				
				#if UNITY_UV_STARTS_AT_TOP
				if (_MainTex_TexelSize.y < 0)
					o.uv.y = 1 - o.uv.y;
				#endif

				// Get the eyespace view ray (normalized)
				o.ray = _FrustumCornersES[(int)index].xyz;
				// Dividing by z "normalizes" it in the z axis
				// Therefore multiplying the ray by some number i gives the viewspace position
				// of the point on the ray with [viewspace z]=i
				o.ray /= abs(o.ray.z);

				// Transform the ray from eyespace to worldspace
				o.ray = mul(_CameraInvViewMatrix, o.ray);

				return o;
			}

			// This is the distance field function.  The distance field represents the closest distance to the surface
			// of any object we put in the scene.  If the given point (point p) is inside of an object, we return a
			// negative answer.
			float2 map(float3 p) 
			{
				//float c = 0.45*cos( float4(0.5,3.9,1.4,1.1) + _Time.y*float4(1.2,1.7,1.3,2.5) ) - float4(0.3,0.0,0.0,0.0); //Alternate C value for Juliabulb
			    float4 c = 0.45* cos( float4(0.5,3.9,1.4,1.1) + _Time.y * float4(1.2,1.7,1.3,2.5) ) - float4(0.3,0.0,0.0,0.0);
				float3 mandelbulbPos = float3(0, 0, 0);
				float3 juliaPos = float3(3, 0, 0);
				float3 juliabulbPos = float3(-3, 0, 0);

				float sinTime = sin(_Time.y / 1);
				float power = remap(sinTime, -1, 1, 4, 9);

				float distances[3] =
				{
					sdDinamMandelbulb(p + mandelbulbPos, power),
					sdJulia(p + juliaPos, c),
					sdJuliabulb(p + juliabulbPos, c)
				};				
				
				float min1 = min(distances[0], distances[1]);
				float distance = min(min1, distances[2]);

				int index;
				for(int i = 0; i < 5; i++)
				{
					if(distances[i] == distance)
					{
						index = i;
						break;
					}
				}

				return float2(distance, index);
			}

			float3 calcNormal(in float3 pos)
			{
				const float2 eps = float2(0.001, 0.0);
				// The idea here is to find the "gradient" of the distance field at pos
				// Remember, the distance field is not boolean - even if you are inside an object
				// the number is negative, so this calculation still works.
				// Essentially you are approximating the derivative of the distance field at this point.
				float3 nor = float3(
					map(pos + eps.xyy).x - map(pos - eps.xyy).x,
					map(pos + eps.yxy).x - map(pos - eps.yxy).x,
					map(pos + eps.yyx).x - map(pos - eps.yyx).x);
				return normalize(nor);
			}

			// Raymarch along given ray
			// ro: ray origin
			// rd: ray direction
			// s: unity depth buffer
			fixed4 raymarch(float3 origin, float3 direction, float depth, out float steps, out bool hit) {
				hit = true;
				
				fixed4 ret = fixed4(0,0,0,0);

				const int maxstep = 64;
				float traveledDist = 0; // current distance traveled along ray
				[loop]
				for (int i = 0; i < 64; ++i) {
					// If we run past the depth buffer, or if we exceed the max draw distance,
					// stop and return nothing (transparent pixel).
					// this way raymarched objects and traditional meshes can coexist.
					if (traveledDist >= depth || traveledDist > _DrawDistance) {
						break;
					}

					float3 worldPos = origin + direction * traveledDist;
					float2 dist = map(worldPos);

					if (dist.x < 0.001) {
						float3 normal = calcNormal(normal);
						float light = dot(-_LightDir.xyz, normal);
						
						float4 colors[5] =
						{
							_Color1, 
							_Color2,
							_Color3,
							_Color4,
							_Color5
						};

						return colors[dist.y];
					}

					// If the sample > 0, we haven't hit anything yet so we should march forward
					// We step forward by distance d, because d is the minimum distance possible to intersect
					// an object (see map()).
					traveledDist += dist;
					steps = i;
				}
				hit = false;
				return 0;
			}

			fixed4 frag (v2f i) : SV_Target
			{
				// ray direction
				float3 rd = normalize(i.ray.xyz);
				// ray origin (camera position)
				float3 ro = _CameraWS;

				float2 duv = i.uv;
				#if UNITY_UV_STARTS_AT_TOP
				if (_MainTex_TexelSize.y < 0)
					duv.y = 1 - duv.y;
				#endif

				// Convert from depth buffer (eye space) to true distance from camera
				// This is done by multiplying the eyespace depth by the length of the "z-normalized"
				// ray (see vert()).  Think of similar triangles: the view-space z-distance between a point
				// and the camera is proportional to the absolute distance.
				float depth = LinearEyeDepth(tex2D(_CameraDepthTexture, duv).r);
				depth *= length(i.ray);

				//fixed3 col = _Color;//tex2D(_MainTex,i.uv);
				float steps = 0;	
				bool hit;				

		
				fixed4 add = raymarch(ro, rd, depth, steps, hit);

				float ao = 1 - steps / 64;
				return add * ao;
			}
			ENDCG
		}
	}
}
