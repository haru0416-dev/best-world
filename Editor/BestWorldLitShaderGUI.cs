using System.Collections.Generic;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;

namespace BestWorld.Editor
{
    public sealed class BestWorldLitShaderGUI : ShaderGUI
    {
        static readonly string[] LightVolumeDefines =
        {
            "BESTWORLD_HAS_VRC_LIGHT_VOLUMES",
            "BESTWORLD_LIGHTVOLUMES_V3"
        };

        const string LtcgiDefine = "BESTWORLD_HAS_LTCGI";

        public override void OnGUI(MaterialEditor materialEditor, MaterialProperty[] properties)
        {
            var material = materialEditor.target as Material;
            if (material == null)
            {
                return;
            }

            material.enableInstancing = true;

            EditorGUILayout.HelpBox(
                "BestWorld はワールド幾何向けの PBR です。アバター用の全部入りシェーダーではありません。\n" +
                "既定の Packed Map は glTF ORM（R=AO, G=Roughness, B=Metallic）です。",
                MessageType.Info);

            DrawPackageStatus();
            DrawDefineButtons();

            EditorGUILayout.Space();
            DrawSection("Maps");
            DrawProp(materialEditor, properties, "_Color");
            DrawProp(materialEditor, properties, "_MainTex");
            DrawProp(materialEditor, properties, "_MapFormat");
            DrawProp(materialEditor, properties, "_PackedMap");
            var mapFormat = FindProperty("_MapFormat", properties, false);
            if (mapFormat != null && mapFormat.floatValue > 0.5f)
            {
                DrawProp(materialEditor, properties, "_OcclusionMap");
            }

            DrawProp(materialEditor, properties, "_BumpMap");
            DrawProp(materialEditor, properties, "_BumpScale");
            DrawProp(materialEditor, properties, "_EmissionMap");
            DrawProp(materialEditor, properties, "_EmissionColor");
            DrawProp(materialEditor, properties, "_EmissionGIMultiplier");

            EditorGUILayout.Space();
            DrawSection("Material");
            DrawProp(materialEditor, properties, "_Metallic");
            DrawProp(materialEditor, properties, "_Roughness");
            DrawProp(materialEditor, properties, "_Glossiness");
            DrawProp(materialEditor, properties, "_OcclusionStrength");
            DrawProp(materialEditor, properties, "_Reflectance");
            DrawProp(materialEditor, properties, "_SpecularWeight");
            DrawProp(materialEditor, properties, "_F82Tint");
            DrawProp(materialEditor, properties, "_UseVertexColor");

            EditorGUILayout.Space();
            DrawSection("Lighting (PC)");
            DrawProp(materialEditor, properties, "_BicubicLightmap");
            DrawProp(materialEditor, properties, "_BakeryMonoSH");
            DrawProp(materialEditor, properties, "_LTCGI");
            DrawProp(materialEditor, properties, "_DETAIL_MAP");
            DrawProp(materialEditor, properties, "_PARALLAXMAP");
            DrawProp(materialEditor, properties, "_CLEARCOAT");

            var detail = FindProperty("_DETAIL_MAP", properties, false);
            if (detail != null && detail.floatValue > 0.5f)
            {
                DrawProp(materialEditor, properties, "_DetailAlbedoMap");
                DrawProp(materialEditor, properties, "_DetailNormalMap");
                DrawProp(materialEditor, properties, "_DetailAlbedoScale");
                DrawProp(materialEditor, properties, "_DetailNormalScale");
            }

            var parallax = FindProperty("_PARALLAXMAP", properties, false);
            if (parallax != null && parallax.floatValue > 0.5f)
            {
                DrawProp(materialEditor, properties, "_ParallaxMap");
                DrawProp(materialEditor, properties, "_Parallax");
            }

            var coat = FindProperty("_CLEARCOAT", properties, false);
            if (coat != null && coat.floatValue > 0.5f)
            {
                DrawProp(materialEditor, properties, "_CoatWeight");
                DrawProp(materialEditor, properties, "_CoatRoughness");
                DrawProp(materialEditor, properties, "_CoatMaskMap");
            }

            EditorGUILayout.Space();
            DrawSection("Render");
            DrawProp(materialEditor, properties, "_Cull");
            if (material.shader != null && material.shader.name.Contains("Cutout"))
            {
                DrawProp(materialEditor, properties, "_Cutoff");
            }

            var premultiply = FindProperty("_ALPHAPREMULTIPLY_ON", properties, false);
            if (premultiply != null)
            {
                DrawProp(materialEditor, properties, "_ALPHAPREMULTIPLY_ON");
                ApplyTransparentBlend(material, premultiply.floatValue > 0.5f);
            }

            DrawProp(materialEditor, properties, "_DebugView");

            EditorGUILayout.Space();
            materialEditor.RenderQueueField();
            materialEditor.EnableInstancingField();
            materialEditor.DoubleSidedGIField();
        }

        static void DrawSection(string title)
        {
            EditorGUILayout.LabelField(title, EditorStyles.boldLabel);
        }

        static void DrawProp(MaterialEditor editor, MaterialProperty[] properties, string name)
        {
            var prop = FindProperty(name, properties, false);
            if (prop != null)
            {
                editor.ShaderProperty(prop, prop.displayName);
            }
        }

        static void ApplyTransparentBlend(Material material, bool premultiply)
        {
            if (premultiply)
            {
                material.SetInt("_SrcBlend", (int)BlendMode.One);
                material.SetInt("_DstBlend", (int)BlendMode.OneMinusSrcAlpha);
            }
            else
            {
                material.SetInt("_SrcBlend", (int)BlendMode.SrcAlpha);
                material.SetInt("_DstBlend", (int)BlendMode.OneMinusSrcAlpha);
            }
        }

        static void DrawPackageStatus()
        {
            bool volumes = HasFile(
                "Packages/red.sim.lightvolumes/Shaders/LightVolumes.cginc");
            bool ltcgi = HasFile(
                "Packages/at.pimaker.ltcgi/Shaders/LTCGI.cginc");

            EditorGUILayout.LabelField("Optional packages", EditorStyles.boldLabel);
            EditorGUILayout.LabelField(
                "VRC Light Volumes",
                volumes ? "found" : "not installed");
            EditorGUILayout.LabelField(
                "LTCGI",
                ltcgi ? "found" : "not installed");
        }

        static void DrawDefineButtons()
        {
            EditorGUILayout.BeginHorizontal();
            if (GUILayout.Button("Enable Light Volumes compile"))
            {
                AddDefines(LightVolumeDefines);
            }

            if (GUILayout.Button("Enable LTCGI compile"))
            {
                AddDefines(new[] { LtcgiDefine });
            }
            EditorGUILayout.EndHorizontal();

            if (GUILayout.Button("Remove BestWorld lighting defines"))
            {
                RemoveDefines(LightVolumeDefines.Concat(new[] { LtcgiDefine }).ToArray());
            }
        }

        static bool HasFile(string path)
        {
            return File.Exists(Path.Combine(Directory.GetCurrentDirectory(), path));
        }

        static void AddDefines(IEnumerable<string> defines)
        {
            var group = EditorUserBuildSettings.selectedBuildTargetGroup;
            var current = PlayerSettings.GetScriptingDefineSymbolsForGroup(group)
                .Split(';')
                .Where(d => !string.IsNullOrWhiteSpace(d))
                .ToList();
            foreach (var define in defines)
            {
                if (!current.Contains(define))
                {
                    current.Add(define);
                }
            }

            PlayerSettings.SetScriptingDefineSymbolsForGroup(group, string.Join(";", current.ToArray()));
        }

        static void RemoveDefines(IEnumerable<string> defines)
        {
            var group = EditorUserBuildSettings.selectedBuildTargetGroup;
            var remove = new HashSet<string>(defines);
            var current = PlayerSettings.GetScriptingDefineSymbolsForGroup(group)
                .Split(';')
                .Where(d => !string.IsNullOrWhiteSpace(d) && !remove.Contains(d));
            PlayerSettings.SetScriptingDefineSymbolsForGroup(group, string.Join(";", current.ToArray()));
        }
    }
}
