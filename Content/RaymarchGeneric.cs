using UnityEngine;

[ExecuteInEditMode]
[RequireComponent(typeof(Camera))]
[AddComponentMenu("Effects/Raymarch (Generic Complete)")]
public class RaymarchGeneric : SceneViewFilter
{
    public Transform SunLight;

	private Shader EffectShader
    {
		get { return Shader.Find("Hidden/RaymarchGeneric"); }
	}

	[SerializeField]
    private float _RaymarchDrawDistance = 40;

    [SerializeField]
    private Color color1;
    [SerializeField]
	private Color color2;
    [SerializeField]
	private Color color3;
    [SerializeField]
	private Color color4;
	[SerializeField]
	private Color color5;

    public Material EffectMaterial
    {
        get
        {
            if (!_EffectMaterial && EffectShader)
            {
                _EffectMaterial = new Material(EffectShader);
                _EffectMaterial.hideFlags = HideFlags.HideAndDontSave;
            }

            return _EffectMaterial;
        }
    }
    private Material _EffectMaterial;

    public Camera CurrentCamera
    {
        get
        {
            if (!_CurrentCamera)
                _CurrentCamera = GetComponent<Camera>();
            return _CurrentCamera;
        }
    }
    private Camera _CurrentCamera;
 
   
    [ImageEffectOpaque]
    void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        if (!EffectMaterial)
        {
            Graphics.Blit(source, destination);
            return;
        }

		EffectMaterial.SetColor("_Color1", color1);
		EffectMaterial.SetColor("_Color2", color2);
		EffectMaterial.SetColor("_Color3", color3);
		EffectMaterial.SetColor("_Color4", color4);
		EffectMaterial.SetColor("_Color5", color5);
		EffectMaterial.SetVector("_LightDir", SunLight ? SunLight.forward : Vector3.down);
        EffectMaterial.SetFloat("_DrawDistance", _RaymarchDrawDistance);
		EffectMaterial.SetVector("_CameraWP", CurrentCamera.transform.position);
		EffectMaterial.SetFloat("_FovX", CurrentCamera.fieldOfView * Mathf.Deg2Rad);
        EffectMaterial.SetVector("_CamForward", CurrentCamera.transform.forward.normalized);
        EffectMaterial.SetVector("_CamUp", CurrentCamera.transform.up.normalized);
        EffectMaterial.SetVector("_CamRight", CurrentCamera.transform.right.normalized);
		EffectMaterial.SetFloat("_AspectRatio", CurrentCamera.aspect);

		Graphics.Blit(source, destination, EffectMaterial);
    }
}
