#include <gtest/gtest.h>
#include "fast/interpreter.h"
#include <algorithm>
#include <vector>

namespace {
using namespace Fast;

// Exercise the real interpreter, recording only the final backend upload.
class UploadRecorder final : public GfxRenderingAPI {
  public:
    int limit = 16384;
    uint32_t width = 0, height = 0;
    int calls = 0;
    std::vector<uint8_t> pixels;
    int GetMaxTextureSize() override { return limit; }
    void UploadTexture(const uint8_t* data, uint32_t w, uint32_t h) override {
        ++calls;
        width = w;
        height = h;
        EXPECT_LE(w, static_cast<uint32_t>(limit));
        EXPECT_LE(h, static_cast<uint32_t>(limit));
        pixels.assign(data, data + static_cast<size_t>(w) * h * 4);
    }
    const char* GetName() override { ADD_FAILURE() << "Unexpected GetName"; return {}; }
    GfxClipParameters GetClipParameters() override { ADD_FAILURE() << "Unexpected GetClipParameters"; return {}; }
    void UnloadShader(ShaderProgram* oldPrg) override { ADD_FAILURE() << "Unexpected UnloadShader"; }
    void LoadShader(ShaderProgram* newPrg) override { ADD_FAILURE() << "Unexpected LoadShader"; }
    void ClearShaderCache() override { ADD_FAILURE() << "Unexpected ClearShaderCache"; }
    ShaderProgram* CreateAndLoadNewShader(uint64_t shaderId0, uint64_t shaderId1) override { ADD_FAILURE() << "Unexpected CreateAndLoadNewShader"; return {}; }
    ShaderProgram* LookupShader(uint64_t shaderId0, uint64_t shaderId1) override { ADD_FAILURE() << "Unexpected LookupShader"; return {}; }
    void ShaderGetInfo(ShaderProgram* prg, uint8_t* numInputs, bool usedTextures[2]) override { ADD_FAILURE() << "Unexpected ShaderGetInfo"; }
    uint32_t NewTexture() override { ADD_FAILURE() << "Unexpected NewTexture"; return {}; }
    void SelectTexture(int tile, uint32_t textureId) override { ADD_FAILURE() << "Unexpected SelectTexture"; }
    void SetSamplerParameters(int sampler, bool linear_filter, uint32_t cms, uint32_t cmt) override { ADD_FAILURE() << "Unexpected SetSamplerParameters"; }
    void SetDepthTestAndMask(bool depth_test, bool z_upd) override { ADD_FAILURE() << "Unexpected SetDepthTestAndMask"; }
    void SetZmodeDecal(bool decal) override { ADD_FAILURE() << "Unexpected SetZmodeDecal"; }
    void SetViewport(int x, int y, int width, int height) override { ADD_FAILURE() << "Unexpected SetViewport"; }
    void SetScissor(int x, int y, int width, int height) override { ADD_FAILURE() << "Unexpected SetScissor"; }
    void SetUseAlpha(bool useAlpha) override { ADD_FAILURE() << "Unexpected SetUseAlpha"; }
    void DrawTriangles(float buf_vbo[], size_t buf_vbo_len, size_t buf_vbo_num_tris) override { ADD_FAILURE() << "Unexpected DrawTriangles"; }
    void Init() override { ADD_FAILURE() << "Unexpected Init"; }
    void OnResize() override { ADD_FAILURE() << "Unexpected OnResize"; }
    void StartFrame() override { ADD_FAILURE() << "Unexpected StartFrame"; }
    void EndFrame() override { ADD_FAILURE() << "Unexpected EndFrame"; }
    void FinishRender() override { ADD_FAILURE() << "Unexpected FinishRender"; }
    int CreateFramebuffer() override { ADD_FAILURE() << "Unexpected CreateFramebuffer"; return {}; }
    void UpdateFramebufferParameters(int fb_id, uint32_t width, uint32_t height, uint32_t msaa_level, bool opengl_invertY, bool render_target, bool has_depth_buffer, bool can_extract_depth) override { ADD_FAILURE() << "Unexpected UpdateFramebufferParameters"; }
    void StartDrawToFramebuffer(int fbId, float noiseScale) override { ADD_FAILURE() << "Unexpected StartDrawToFramebuffer"; }
    void CopyFramebuffer(int fbDstId, int fbSrcId, int srcX0, int srcY0, int srcX1, int srcY1, int dstX0, int dstY0, int dstX1, int dstY1) override { ADD_FAILURE() << "Unexpected CopyFramebuffer"; }
    void ClearFramebuffer(bool color, bool depth) override { ADD_FAILURE() << "Unexpected ClearFramebuffer"; }
    void ReadFramebufferToCPU(int, uint32_t, uint32_t, uint16_t*) override { ADD_FAILURE() << "Unexpected ReadFramebufferToCPU"; }
    void ResolveMSAAColorBuffer(int fbIdTarger, int fbIdSrc) override { ADD_FAILURE() << "Unexpected ResolveMSAAColorBuffer"; }
    std::unordered_map<std::pair<float, float>, uint16_t, hash_pair_ff> GetPixelDepth(int fb_id, const std::set<std::pair<float, float>>& coordinates) override { ADD_FAILURE() << "Unexpected GetPixelDepth"; return {}; }
    void* GetFramebufferTextureId(int fbId) override { ADD_FAILURE() << "Unexpected GetFramebufferTextureId"; return {}; }
    void SelectTextureFb(int fbId) override { ADD_FAILURE() << "Unexpected SelectTextureFb"; }
    void DeleteTexture(uint32_t texId) override { ADD_FAILURE() << "Unexpected DeleteTexture"; }
    void SetTextureFilter(FilteringMode mode) override { ADD_FAILURE() << "Unexpected SetTextureFilter"; }
    FilteringMode GetTextureFilter() override { ADD_FAILURE() << "Unexpected GetTextureFilter"; return {}; }
    void SetSrgbMode() override { ADD_FAILURE() << "Unexpected SetSrgbMode"; }
    ImTextureID GetTextureById(int id) override { ADD_FAILURE() << "Unexpected GetTextureById"; return {}; }
    void SetCurrentPrimDepth(float depth) override { ADD_FAILURE() << "Unexpected SetCurrentPrimDepth"; }
};

void CheckUpload(uint16_t imageWidth, uint16_t imageHeight, uint32_t loadedBytes,
                 uint32_t packedStride, uint32_t tileStride,
                 uint32_t expectedWidth, uint32_t expectedHeight) {
    for (int limit : {8192, 16384}) {
        SCOPED_TRACE(limit);
        Interpreter interpreter;
        UploadRecorder backend;
        backend.limit = limit;
        interpreter.mRapi = &backend;
        const size_t imageBytes = static_cast<size_t>(imageWidth) * imageHeight * 4;
        std::vector<uint8_t> image(imageBytes), upload(std::max<size_t>(loadedBytes, imageBytes));
        for (size_t i = 0; i < image.size(); ++i) image[i] = static_cast<uint8_t>((i * 17 + i / 256) % 251);
        interpreter.mTexUploadBuffer = upload.data();
        auto& tile = interpreter.mRdp->texture_tile[0];
        tile.tmem_index = 0;
        tile.siz = G_IM_SIZ_16b;
        tile.line_size_bytes = tileStride;
        auto& texture = interpreter.mRdp->loaded_texture[0];
        texture.addr = image.data();
        texture.size_bytes = texture.orig_size_bytes = loadedBytes;
        texture.line_size_bytes = texture.full_image_line_size_bytes = packedStride;
        auto& metadata = texture.raw_tex_metadata;
        metadata.width = imageWidth;
        metadata.height = imageHeight;
        metadata.h_byte_scale = metadata.v_pixel_scale = 1;
        metadata.type = TextureType::RGBA32bpp;
        metadata.resource = std::make_shared<Texture>(std::make_shared<Ship::ResourceInitData>());
        metadata.resource->ImageDataSize = imageBytes;
        interpreter.ImportTextureRaw(0, false);
        EXPECT_EQ(backend.calls, 1);
        EXPECT_EQ(backend.width, expectedWidth);
        EXPECT_EQ(backend.height, expectedHeight);
        std::vector<uint8_t> expected(image.begin(), image.begin() + expectedWidth * expectedHeight * 4);
        EXPECT_EQ(backend.pixels, expected);
    }
}

TEST(RawTextureUpload, FullImageSingleLineExceedsMetalLimit) {
    CheckUpload(256, 256, 262144, 262144, 32, 256, 256);
}
TEST(RawTextureUpload, PartialImageUsesTileDimensions) {
    CheckUpload(256, 256, 131072, 131072, 1024, 256, 128);
}
TEST(RawTextureUpload, SingleLineBelowLimitStillKeepsImageShape) {
    CheckUpload(64, 64, 16384, 16384, 32, 64, 64);
}
TEST(RawTextureUpload, OrdinaryMultiRowUploadKeepsPackedStride) {
    CheckUpload(256, 256, 8192, 128, 128, 32, 64);
}
TEST(RawTextureUpload, DirectImageUploadIsUnchanged) {
    CheckUpload(64, 64, 16384, 256, 256, 64, 64);
}
TEST(RawTextureUpload, OversizedLoadIsLimitedToResourcePixels) {
    CheckUpload(256, 256, 524288, 524288, 32, 256, 256);
}
} // namespace
