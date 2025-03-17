# For more information about using CMake with Android Studio, read the
# documentation: https://d.android.com/studio/projects/add-native-code.html

# Set the minimum required version of CMake
cmake_minimum_required(VERSION 3.22.1)

# Set standards for C and C++
set(CMAKE_C_STANDARD 99)
set(CMAKE_CXX_STANDARD 11)

# Set the project name based on the name given on the gradle.properties
project("${APP_LIB_NAME}")

# Include raylib and raymob as a subdirectories
add_subdirectory(${CMAKE_SOURCE_DIR}/vendor/raylib)
add_subdirectory(${CMAKE_SOURCE_DIR}/vendor/raymob)

# Fetch all source files for your project (recursively), excluding 'vendor' source files
file(GLOB_RECURSE SOURCES "${CMAKE_SOURCE_DIR}/*.c" "${CMAKE_SOURCE_DIR}/*.cpp")
list(FILTER SOURCES EXCLUDE REGEX "${CMAKE_SOURCE_DIR}/vendor/.*")

# Add headers directory for android_native_app_glue.c
include_directories(${ANDROID_NDK}/sources/android/native_app_glue/)

# Add android_native_app_glue.c to the source files
list(APPEND SOURCES ${ANDROID_NDK}/sources/android/native_app_glue/android_native_app_glue.c)

# Create a shared library with game source files
add_library(${APP_LIB_NAME} SHARED ${SOURCES})

# Define compiler macros for the library
target_compile_definitions(${APP_LIB_NAME} PRIVATE PLATFORM_ANDROID)

# Apply flags depending on the build type
if(CMAKE_BUILD_TYPE MATCHES "Debug")
    target_compile_definitions(${APP_LIB_NAME} PRIVATE _DEBUG DEBUG)
    set(CMAKE_CXX_FLAGS_DEBUG "-g -fno-limit-debug-info")
    set(CMAKE_C_FLAGS_DEBUG "-g -fno-limit-debug-info")
elseif(CMAKE_BUILD_TYPE MATCHES "Release")
    set(CMAKE_CXX_FLAGS_RELEASE "-O2 -DNDEBUG")
    set(CMAKE_C_FLAGS_RELEASE "-O2 -DNDEBUG")
endif()

# Include raylib and raymob header files
target_include_directories(${APP_LIB_NAME} PRIVATE "${CMAKE_SOURCE_DIR}/vendor/raylib")
target_include_directories(${APP_LIB_NAME} PRIVATE "${CMAKE_SOURCE_DIR}/vendor/raymob")

# Link required libraries to the native application
target_link_libraries(${APP_LIB_NAME} raylib raymoblib)

set(BEEF_PROJECT_PATH "${CMAKE_SOURCE_DIR}/../../../../MinesweeperAndroid")
set(APP_LIBS_DIR "${CMAKE_SOURCE_DIR}/libs/")

if(CMAKE_BUILD_TYPE MATCHES "Debug")
    set(BEEF_PROJECT_CONFIG "Debug")
elseif(CMAKE_BUILD_TYPE MATCHES "Release")
    set(BEEF_PROJECT_CONFIG "Release")
endif()

if (${ANDROID_ABI} STREQUAL "arm64-v8a")
    set(BEEF_ARCH "${BEEF_PROJECT_CONFIG}_aarch64-none-linux-android23")
elseif (${ANDROID_ABI} STREQUAL "armeabi-v7a")
    set(BEEF_ARCH "${BEEF_PROJECT_CONFIG}_armv7-none-linux-androideabi23")
elseif (${ANDROID_ABI} STREQUAL "x86_64")
    set(BEEF_ARCH "${BEEF_PROJECT_CONFIG}_x86_64-none-linux-android23")
elseif (${ANDROID_ABI} STREQUAL "x86")
    set(BEEF_ARCH "${BEEF_PROJECT_CONFIG}_i686-none-linux-android23")
endif()

# Unfortunately, we'll disable libffi for this project
# We don't need it for this game, but getting it working shouldn't be *too* difficult if required..?
set(BF_DISABLE_FFI ON)

# Link and include BeefRT to the native application
add_subdirectory(${CMAKE_SOURCE_DIR}/vendor/beef/BeefRT)
target_link_libraries(${APP_LIB_NAME} BeefRT)

# Link the game logic to the native application
target_link_libraries(${APP_LIB_NAME}
        ${BEEF_PROJECT_PATH}/build/${BEEF_ARCH}/MinesweeperAndroid/MinesweeperAndroid.a
        ${APP_LIBS_DIR}/${ANDROID_ABI}/libffi.a
)