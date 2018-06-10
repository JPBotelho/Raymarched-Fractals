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

			uniform float3 _LightDir;
			uniform float _DrawDistance;

			uniform float4 _Color1;
			uniform float4 _Color2;
			uniform float4 _Color3;
			uniform float4 _Color4;
			uniform float4 _Color5;

			float3 _CameraWP;

			float3 _CamForward;
			float3 _CamRight;
			float3 _CamUp;
			float _FovX;
			float _AspectRatio;

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float4 pos : SV_POSITION;
				float2 uv : TEXCOORD0;
			};

			float2 map(float3 p) 
			{
				//return length(p) - 1;
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
			
			fixed4 raymarch(float3 origin, float3 direction, float depth, out float steps, out bool hit, out float light) 
			{
				hit = true;				
				const int maxstep = 64;
				float traveledDist = 0;

				[loop]
				for (int i = 0; i < maxstep; ++i) 
				{					
					if (traveledDist > _DrawDistance || traveledDist > depth)
					{
						break;
					}

					float3 worldPos = origin + direction * traveledDist;
					float2 dist = map(worldPos);

					if (dist.x < 0.001) 
					{
						float3 normal = calcNormal(worldPos);
						light = dot(-_LightDir.xyz, normal);

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
					
					traveledDist += dist;
					steps = i;
				}
				hit = false;
				return 0;
			}


			v2f vert (appdata v)
			{
				v2f o;				
				o.pos = UnityObjectToClipPos(v.vertex);
				o.uv = v.uv.xy;
				
				#if UNITY_UV_STARTS_AT_TOP
				if (_MainTex_TexelSize.y < 0)
					o.uv.y = 1 - o.uv.y;
				#endif
			
				return o;
			}

	
			fixed4 frag (v2f i) : SV_Target
			{
				float3 origin = _CameraWP;
				float xUV = 2.0 * i.uv.x - 1.0;
				float yUV = 2.0 * i.uv.y - 1.0;
				float3 direction = normalize(_CamForward + tan(_FovX/2.0)*_AspectRatio*xUV*_CamRight + tan(_FovX/2.0)*yUV*_CamUp);

				#if UNITY_UV_STARTS_AT_TOP
				if (_MainTex_TexelSize.y < 0)
					i.uv.y = 1 - i.uv.y;
				#endif

				float depth = LinearEyeDepth(tex2D(_CameraDepthTexture, i.uv).r);
		
				//Out paramters
				float steps = 0;	
				bool hit;				
				float light;
				fixed4 color = raymarch(origin, direction, depth, steps, hit, light);

				float ao = 1 - steps / 64;
				return ao * color;
			}
			ENDCG
		}
	}
}
