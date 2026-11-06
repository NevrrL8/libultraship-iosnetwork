include(FetchContent)

#=================== SDL2 ===================
find_package(SDL2 QUIET)
if (NOT ${SDL2_FOUND})
    # SDL 2.32.10 predates UIKit scene startup required by the latest SDK.
    # Preserve local edits while applying the maintained scenes and orientation fixes.
    set(sdl2_scene_patch ${CMAKE_CURRENT_SOURCE_DIR}/cmake/dependencies/patches/sdl2-uikit-scenes.patch)
    set(sdl2_orientation_patch ${CMAKE_CURRENT_SOURCE_DIR}/cmake/dependencies/patches/sdl2-uikit-orientation.patch)
    FetchContent_Declare(
        SDL2
        GIT_REPOSITORY https://github.com/libsdl-org/SDL.git
        GIT_TAG release-2.32.10
        PATCH_COMMAND ${CMAKE_COMMAND} -Dpatch_file=${sdl2_scene_patch}
            -Dfallback_patch_file=${sdl2_orientation_patch}
            -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/dependencies/git-patch.cmake
        OVERRIDE_FIND_PACKAGE
    )
    FetchContent_MakeAvailable(SDL2)
endif()

# Upgrade populated scene-only caches too; never modify an installed SDL2 package.
FetchContent_GetProperties(SDL2)
if (sdl2_POPULATED)
    execute_process(
        COMMAND ${CMAKE_COMMAND}
            -Dpatch_file=${CMAKE_CURRENT_SOURCE_DIR}/cmake/dependencies/patches/sdl2-uikit-scenes.patch
            -Dfallback_patch_file=${CMAKE_CURRENT_SOURCE_DIR}/cmake/dependencies/patches/sdl2-uikit-orientation.patch
            -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/dependencies/git-patch.cmake
        WORKING_DIRECTORY ${sdl2_SOURCE_DIR}
        RESULT_VARIABLE sdl2_orientation_result
    )
    if (NOT sdl2_orientation_result EQUAL 0)
        message(FATAL_ERROR "SDL2 scene orientation patch failed; dependency files were preserved.")
    endif()
endif()

# =================== SDL2_net ===================
set(SDL2NET_INSTALL OFF CACHE BOOL "" FORCE)
set(SDL2NET_SAMPLES OFF CACHE BOOL "" FORCE)

FetchContent_Declare(
    SDL2_net
    GIT_REPOSITORY https://github.com/libsdl-org/SDL_net.git
    GIT_TAG release-2.2.0
)
FetchContent_MakeAvailable(SDL2_net)

if(NOT TARGET SDL2_net::SDL2_net-static)
    message(FATAL_ERROR "SDL2_net static target is unavailable")
endif()


#=================== nlohmann-json ===================
find_package(nlohmann_json QUIET)
if (NOT ${nlohmann_json_FOUND})
    FetchContent_Declare(
        nlohmann_json
        GIT_REPOSITORY https://github.com/nlohmann/json.git
        GIT_TAG v3.12.0
        OVERRIDE_FIND_PACKAGE
    )
    FetchContent_MakeAvailable(nlohmann_json)
endif()

#=================== tinyxml2 ===================
find_package(tinyxml2 QUIET)
if (NOT ${tinyxml2_FOUND})
    set(tinyxml2_BUILD_TESTING OFF)
    FetchContent_Declare(
        tinyxml2
        GIT_REPOSITORY https://github.com/leethomason/tinyxml2.git
        GIT_TAG 11.0.0
        OVERRIDE_FIND_PACKAGE
    )
    FetchContent_MakeAvailable(tinyxml2)
endif()

#=================== spdlog ===================
find_package(spdlog QUIET)
if (NOT ${spdlog_FOUND})
    FetchContent_Declare(
        spdlog
        GIT_REPOSITORY https://github.com/gabime/spdlog.git
        GIT_TAG v1.16.0
        OVERRIDE_FIND_PACKAGE
    )
    FetchContent_MakeAvailable(spdlog)
endif()

#=================== libzip ===================
find_package(libzip QUIET)
if (NOT ${libzip_FOUND})
    set(CMAKE_POLICY_DEFAULT_CMP0077 NEW)
    set(BUILD_TOOLS OFF)
    set(BUILD_REGRESS OFF)
    set(BUILD_EXAMPLES OFF)
    set(BUILD_DOC OFF)
    set(BUILD_OSSFUZZ OFF)
    set(BUILD_SHARED_LIBS OFF)
    FetchContent_Declare(
        libzip
        GIT_REPOSITORY https://github.com/nih-at/libzip.git
        GIT_TAG v1.11.4
        OVERRIDE_FIND_PACKAGE
    )
    FetchContent_MakeAvailable(libzip)
    list(APPEND ADDITIONAL_LIB_INCLUDES ${libzip_SOURCE_DIR}/lib ${libzip_BINARY_DIR})
endif()

#=================== Metal-cpp ===================
FetchContent_Declare(
    metalcpp
    GIT_REPOSITORY https://github.com/briaguya-ai/single-header-metal-cpp.git
    GIT_TAG macOS13_iOS16
)
FetchContent_MakeAvailable(metalcpp)
list(APPEND ADDITIONAL_LIB_INCLUDES ${metalcpp_SOURCE_DIR})

#=================== ImGui ===================
target_sources(ImGui
    PRIVATE
    ${imgui_SOURCE_DIR}/backends/imgui_impl_metal.mm
)

target_include_directories(ImGui PRIVATE ${metalcpp_SOURCE_DIR})
target_compile_definitions(ImGui PUBLIC IMGUI_IMPL_METAL_CPP)

target_link_libraries(ImGui PUBLIC SDL2::SDL2-static SDL2::SDL2main)
