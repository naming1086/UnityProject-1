Shader "Custom/GrassShader"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Color("TopColor",Color) = (1.0,1.0,1.0,1.0)
        
        _GradientVector("_GradientVector",vector) = (0.0,1.0,0.0,0.0)
        _CutOff("Cutoff",Range(0.0,1.0)) = 0.0
        _WindAnimToggle("_WindAnimToggle",int) = 1
        _SpecularRadius("_SpecularRadius",Range(1.0,100.0)) = 50.0
        _SpecularIntensity("_SpecularIntensity",Range(0.0,1.0)) = 0.5
        _OcclusionIntensity("_OccIntensity",Range(0.0,1.0)) = 0.5
        
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        CGINCLUDE
        #include "../ShaderFunction.hlsl"
        uniform sampler2D _MainTex;
        uniform float _CutOff;
        uniform float4 _Color;

        uniform float4 _GradientVector;
        uniform float _OcclusionIntensity;
        uniform float _SpecularRadius;
        uniform float _SpecularIntensity;
        
        ENDCG
        Pass
        {
            Tags {
                "RenderType"="Opaque"
                "LightMode"="ForwardBase" //这个一定要加，不然阴影会闪烁
                "Queue" = "Geometry"
            } 
            LOD 100
            Cull off
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fwdbase

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float4 color:COLOR;
                float3 normal:NORMAL;
                
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 pos : SV_POSITION;
                float4 localPos:TEXCOORD2;
                float4 vertexColor:COLOR;
                float3 worldNormal:NORMAL;
                float3 worldPos :TEXCOORD3;
                float3 worldView :TEXCOORD4;
                LIGHTING_COORDS(98,99)
            };


            v2f vert (appdata v)
            {
                v2f o;
                UNITY_INITIALIZE_OUTPUT(v2f,o);//初始化顶点着色器
                GRASS_INTERACT(v);
                WIND_ANIM(v);
                
                o.worldPos = mul(unity_ObjectToWorld,v.vertex);
                o.pos = UnityObjectToClipPos(v.vertex);
                o.localPos = v.vertex;
                o.worldNormal = UnityObjectToWorldNormal(v.normal);
                o.uv = v.uv;
                o.vertexColor = v.color;
                o.worldView = _WorldSpaceCameraPos - mul(unity_ObjectToWorld,v.vertex);
                TRANSFER_VERTEX_TO_FRAGMENT(o);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                
                //采样贴图
                fixed4 var_MainTex = tex2D(_MainTex, i.uv);
                //准备向量
                float3 lightDir = normalize(_WorldSpaceLightPos0).xyz;
                float3 viewDir  = normalize(i.worldView);
                float3 normalDir = normalize(i.worldNormal);
                float3 halfDir   = normalize(lightDir + viewDir);
                //点乘计算
                float NdotL = max(0.0,dot(normalDir,lightDir));
                float NdotH = max(0.0,dot(float3(0.0,1.0,0.0),halfDir));//这里假设所有法线朝上
                
                //基础颜色Albedo
                float3 Albedo  = _Color;
                //Occlusion
                float Occlustion = lerp(1,i.vertexColor.a,_OcclusionIntensity);
                //主光源影响
                float specular = pow(NdotH,_SpecularRadius) * _SpecularIntensity * i.vertexColor.a;
                float shadow = SHADOW_ATTENUATION(i);
                float3 lightContribution = (specular +  Albedo * _LightColor0.rgb * NdotL) * shadow * CLOUD_SHADOW(i);
                //环境光源影响
                float3 Ambient = ShadeSH9(float4(normalDir,1));
                float3 indirectionContribution = Ambient * Albedo * Occlustion;
      
                //光照合成
                float3 finalRGB = lightContribution + indirectionContribution;
                BIGWORLD_FOG(i,finalRGB);//大世界雾效
                //AlphaTest
                clip(var_MainTex.g - _CutOff);
                //输出
                return finalRGB.rgbb;
            }
            ENDCG
        }
        
        pass
        {
            Name "ShadowCaster"
            Tags{"LightMode" = "ShadowCaster"}	
            Cull off
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_shadowcaster
            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float4 color:COLOR;
                float3 normal:NORMAL;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };
            
            struct v2f 
            {
                V2F_SHADOW_CASTER;
                float2 uv : TEXCOORD0;
                
            };

            v2f vert (appdata v)
            {
                v2f o;
                GRASS_INTERACT(v);
                WIND_ANIM(v);
                
                o.uv = v.uv;
                TRANSFER_SHADOW_CASTER_NORMALOFFSET(o)
                
                return o;
            }
            float4 frag(v2f i ):SV_Target
            {
                
                fixed4 var_MainTex = tex2D(_MainTex, i.uv);
                clip(var_MainTex.g - _CutOff);
                SHADOW_CASTER_FRAGMENT(i)//这个要放到最后一位
            } 
            ENDCG
        }
        
    }

    CustomEditor "GrassShaderGUI"
}