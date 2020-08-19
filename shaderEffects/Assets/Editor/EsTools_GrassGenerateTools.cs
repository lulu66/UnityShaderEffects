using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;

public class EsTools_GrassGenerateTools : EditorWindow
{
    private Transform GrassRoot = null;

    //支持两种grass prefab
    private GameObject Grass1Prefab = null;
    private GameObject Grass2Prefab = null;

    private bool EnableGrass1;
    private bool EnableGrass2;

    private float MinSize = 0.5f;
    private float MaxSize = 0.5f;
    private bool EnableRandomSize;

    private GameObject GrassPropPrefab;

    private float BrushSize = 0.5f;
    private int GeneratedNum = 10;

    //private GrassInstancing mGrassInstancing;

    private List<GameObject> GrassInstances = new List<GameObject>();

    public List<GameObject> Grasses
    {
        get { return GrassInstances; }
    }

    [MenuItem("ES Tools/Grass Generator Tool")]
    public static void ShowWindow()
    {
        EsTools_GrassGenerateTools window = (EsTools_GrassGenerateTools)EditorWindow.GetWindow(typeof(EsTools_GrassGenerateTools));
        window.Show();
    }

    void onSceneGUI(SceneView sceneView)
    {
        if (!Grass1Prefab && !Grass2Prefab)
            return;

        if ((Event.current.type == EventType.MouseDown && Event.current.button == 1) )
        {
            Ray ray = HandleUtility.GUIPointToWorldRay(Event.current.mousePosition);
            RaycastHit hit;
            if (Physics.Raycast(ray, out hit))
            {
                //GenerateOneGrass(hit);
                GenerateInCircle(hit);
            }
        }
    }

    //以点击点为圆心生成草
    void GenerateInCircle(RaycastHit hit)
    {
        for(int i=0; i<GeneratedNum;i++)
        {
            Vector3 pos = new Vector3(Random.Range(-BrushSize, BrushSize), 0, Random.Range(-BrushSize, BrushSize));
            if((pos.x * pos.x + pos.z * pos.z)<(BrushSize * BrushSize))
            {
                GameObject grassInstance = null;
                if (!(EnableGrass1 || EnableGrass2))
                    return;
                if (EnableGrass1)
                {
                    grassInstance = GameObject.Instantiate<GameObject>(Grass1Prefab);
                }
                if (EnableGrass2 && !EnableGrass1)
                {
                    grassInstance = GameObject.Instantiate<GameObject>(Grass2Prefab);
                }
                grassInstance.transform.parent = GrassRoot;
                grassInstance.transform.position = pos + hit.point;
                grassInstance.transform.localScale = Random.Range(MinSize, MaxSize) * Vector3.one;
                grassInstance.transform.localRotation = Quaternion.AngleAxis(Random.Range(0, 360f), Vector3.up);
                grassInstance.transform.up = Vector3.up;
                grassInstance.gameObject.SetActive(true);
                GrassInstances.Add(grassInstance);
                //mGrassInstancing.DrawInstancedProp(grassInstance);
            }
        }
    }

    //在点击位置生成草
    void GenerateOneGrass(RaycastHit hit)
    {
        GameObject grassInstance = null;
        if (!(EnableGrass1 || EnableGrass2))
            return;
        if (EnableGrass1)
        {
            grassInstance = GameObject.Instantiate<GameObject>(Grass1Prefab);
        }
        if (EnableGrass2 && !EnableGrass1)
        {
            grassInstance = GameObject.Instantiate<GameObject>(Grass2Prefab);
        }
        grassInstance.transform.parent = GrassRoot;
        grassInstance.transform.position = hit.point;
        grassInstance.transform.localScale = Random.Range(MinSize, MaxSize) * Vector3.one;
        grassInstance.transform.localRotation = Quaternion.AngleAxis(Random.Range(0, 360f), Vector3.up);
        grassInstance.transform.up = Vector3.up;
        grassInstance.gameObject.SetActive(true);
        GrassInstances.Add(grassInstance);
        //mGrassInstancing.DrawInstancedProp(grassInstance);
    }

    private void OnFocus()
    {
    }

    private void OnLostFocus()
    {
    }

    private void OnEnable()
    {
        EditorUtility.ClearProgressBar();
        SceneView.onSceneGUIDelegate -= this.onSceneGUI;
        SceneView.onSceneGUIDelegate += this.onSceneGUI;
        //if (mGrassInstancing == null)
        //{
        //    mGrassInstancing = new GrassInstancing(this);
        //}
        //mGrassInstancing.Init();
    }

    void OnDisable()
    {
        SceneView.onSceneGUIDelegate -= this.onSceneGUI;
    }

    private void OnGUI()
    {
        EditorGUILayout.Space();
        BrushSize = EditorGUILayout.FloatField("BrushSize", BrushSize);
        GeneratedNum = EditorGUILayout.IntField("GrassNumOneBlock", GeneratedNum);
        EditorGUILayout.Space();
        Grass1Prefab = EditorGUILayout.ObjectField("Grass1 Prefab", Grass1Prefab, typeof(GameObject), true) as GameObject;
        Grass2Prefab = EditorGUILayout.ObjectField("Grass2 Prefab", Grass2Prefab, typeof(GameObject), true) as GameObject;
        GrassRoot = EditorGUILayout.ObjectField("Grass Root", GrassRoot, typeof(Transform), true) as Transform;
        EnableGrass1 = EditorGUILayout.Toggle("Enable Grass1", EnableGrass1);
        EnableGrass2 = EditorGUILayout.Toggle("Enable Grass2", EnableGrass2);
        EnableRandomSize = EditorGUILayout.Toggle("Enable RandomSize", EnableRandomSize);

        if(EnableRandomSize)
        {
            EditorGUILayout.MinMaxSlider(ref MinSize, ref MaxSize, 0.001f, 1f);
        }

        if (GUILayout.Button("Clear All"))
        {
            if (GrassRoot)
            {
                clearAll();
            }
        }
        //if(GUILayout.Button("CreatePrefab"))
        //{
            
        //    CreatePrefab();
        //}
        //GrassPropPrefab = EditorGUILayout.ObjectField("Generated Prefab", GrassPropPrefab, typeof(GameObject), true) as GameObject;
        //if(GrassPropPrefab!=null )
        //{
        //    if(GUILayout.Button("RefreshGrass"))
        //    {
        //        var asset = GameObject.Instantiate<GameObject>(GrassPropPrefab);
        //        asset.hideFlags = HideFlags.HideAndDontSave;
        //        mGrassInstancing.ReCreateGrass(GrassRoot, asset);
        //        SceneView.RepaintAll();
        //    }
        //}
    }

    //void CreatePrefab()
    //{
    //    string path = "Assets/GrassAndFlower/GrassPrefab.prefab";
    //    GameObject go = mGrassInstancing.CreateGrassGameObject();
    //    PrefabUtility.CreatePrefab(path,go,ReplacePrefabOptions.ConnectToPrefab);
    //    DestroyImmediate(go);
    //}

    void clearAll()
    {
        if(GrassInstances!=null)
        {
            GrassInstances.Clear();
        }
        Transform[] children = GrassRoot.GetComponentsInChildren<Transform>();

        for(int i=1; i<children.Length;i++)
        {
            DestroyImmediate(children[i].gameObject);
        }

        //if(mGrassInstancing!=null)
        //{
        //    mGrassInstancing.Clear();
        //}
    }
}
