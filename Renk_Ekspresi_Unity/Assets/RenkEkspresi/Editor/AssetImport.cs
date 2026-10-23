using UnityEditor;
using UnityEngine;
namespace RenkEkspresi.Editor
{
    public sealed class AssetImport : AssetPostprocessor
    {
        void OnPreprocessAudio()
        {
            if (!assetPath.StartsWith("Assets/RenkEkspresi/Resources/Audio/"))
                return;
            var importer = (AudioImporter)assetImporter;
            var settings = importer.defaultSampleSettings;
            bool loop = assetPath.Contains("calm_journey") || assetPath.Contains("steam_chuffs");
            settings.loadType = loop ? AudioClipLoadType.Streaming : AudioClipLoadType.DecompressOnLoad;
            settings.compressionFormat = AudioCompressionFormat.Vorbis;
            settings.quality = .7f;
            importer.defaultSampleSettings = settings;
            importer.forceToMono = !loop;
        }
        void OnPreprocessTexture()
        {
            if (!assetPath.StartsWith("Assets/RenkEkspresi/Resources/UI/"))
                return;
            var importer = (TextureImporter)assetImporter;
            importer.textureType = TextureImporterType.Default;
            importer.alphaIsTransparency = true;
            importer.mipmapEnabled = false;
            importer.maxTextureSize = 512;
            importer.textureCompression = TextureImporterCompression.Uncompressed;
        }
    }
}
