using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;

public class GrassInstancing : MonoBehaviour {

    private MaterialPropertyBlock mProp;

    private List<GameObject> mGrasses;

    private MeshRenderer mMeshRender;

    private List<Color> mColorProps;
    private GrassProps mGrassProps;

    private EsTools_GrassGenerateTools mGrassWindow;

    private bool Initialized = false;
    public GrassInstancing(EsTools_GrassGenerateTools grassWindow)
    {
        mGrassWindow = grassWindow;
    }


    public void Init()
    {
        mProp = new MaterialPropertyBlock();
        mColorProps = new List<Color>();
        Initialized = true;
    }

    public GameObject CreateGrassGameObject()
    {
        GameObject go = new GameObject("GrassProps");
        mGrassProps = go.AddComponent<GrassProps>();
        mGrassProps.GrassColors = mColorProps;
        return go;
    }

    public void DrawInstancedProp(GameObject grass)
    {
        if(mProp==null)
        {
            mProp = new MaterialPropertyBlock();
        }
        mMeshRender = grass.GetComponent<MeshRenderer>();
        Color color = new Color(Random.Range(0.0f, 1.0f), Random.Range(0.0f, 1.0f), Random.Range(0.0f, 1.0f));
        mProp.SetColor("_Color", color);
        mColorProps.Add(color);
        mMeshRender.SetPropertyBlock(mProp);
    }

    public void ReCreateGrass(Transform root, GameObject prefab)
    {
        if(!Initialized)
        {
            Init();
        }
        Transform[] grassChildren = root.GetComponentsInChildren<Transform>();
        List<Color> colors = prefab.GetComponent<GrassProps>().GrassColors;
        for (int i = 1; i < grassChildren.Length; i++)
        {
            var child = grassChildren[i].gameObject;
            mGrassWindow.Grasses.Add(child);
            if (mProp == null)
            {
                mProp = new MaterialPropertyBlock();
            }
            mMeshRender = grassChildren[i].GetComponent<MeshRenderer>();
            mProp.SetColor("_Color", colors[i-1]);
            mMeshRender.SetPropertyBlock(mProp);
        }
    }
    public void Clear()
    {
    }
}
