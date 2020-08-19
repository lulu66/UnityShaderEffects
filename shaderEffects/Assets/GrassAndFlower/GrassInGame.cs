using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class GrassInGame : MonoBehaviour {

    public GameObject mGrassPropAsset;
    public Transform mGrassRoot;
    private List<Color> mGrassColors;
    private Transform[] mGrassChildren;
    private MaterialPropertyBlock mProp;
    private MeshRenderer mMeshRender;
	void Start () {
        InitProps();
        mProp = new MaterialPropertyBlock();
        mGrassChildren = mGrassRoot.GetComponentsInChildren<Transform>();
    }
	
    void InitProps()
    {
        var asset = GameObject.Instantiate<GameObject>(mGrassPropAsset);
        mGrassColors = asset.GetComponent<GrassProps>().GrassColors;
    }
    void Update () {
        //排除父节点
		for(int i=1; i<mGrassChildren.Length; i++)
        {
            if (mProp == null)
            {
                mProp = new MaterialPropertyBlock();
            }
            mMeshRender = mGrassChildren[i].GetComponent<MeshRenderer>();
            mProp.SetColor("_Color", mGrassColors[i-1]);
            mMeshRender.SetPropertyBlock(mProp);
        }
	}
}
