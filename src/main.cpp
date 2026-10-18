//---------------------------------------
/// @file   main.cpp
///
/// @brief  GLFW と Vulkan SDK のビルド設定が通っていることを確かめるエントリーポイント.
///
/// @date   2026/10/18
///
/// @author 轟龍
//---------------------------------------

// NOTE:
// glfw3.h は Vulkan 関連の宣言を出すかどうかをこのマクロで判断する.
// インクルードより前に定義しないと glfwCreateWindowSurface が宣言されない.
#define GLFW_INCLUDE_VULKAN

#include <cstdint>
#include <cstdio>
#include <cstdlib>

#include <GLFW/glfw3.h>
#include <vulkan/vulkan.h>

// TODO:
// 三角形の描画はまだ入っていない. ここはインクルードパスとリンク設定の確認用で、
// GLFW と Vulkan の両方が解決できていればバージョンを表示して終了する.
int main()
{
    if (glfwInit() != GLFW_TRUE)
    {
        std::printf("GLFW の初期化に失敗しました.\n");

        return EXIT_FAILURE;
    }

    std::uint32_t instanceApiVersion{};

    if (vkEnumerateInstanceVersion(&instanceApiVersion) != VK_SUCCESS)
    {
        std::printf("Vulkan のインスタンスバージョンを取得できませんでした.\n");
        glfwTerminate();

        return EXIT_FAILURE;
    }

    std::printf("GLFW %s\n", glfwGetVersionString());
    std::printf("Vulkan %u.%u.%u\n",
                VK_API_VERSION_MAJOR(instanceApiVersion),
                VK_API_VERSION_MINOR(instanceApiVersion),
                VK_API_VERSION_PATCH(instanceApiVersion));

    glfwTerminate();

    return EXIT_SUCCESS;
}
