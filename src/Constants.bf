using System;
namespace Minesweeper;

static
{
#if GAME_SCREEN_CONSTANT
	public const int SCREEN_WIDTH = 320 * 2;
	public const int SCREEN_HEIGHT = 180 * 2;

	public const float SCREEN_ASPECT_RATIO = (float)SCREEN_WIDTH / (float)SCREEN_HEIGHT;
#elif GAME_SCREEN_FREE
	public static int32 SCREEN_WIDTH => RaylibBeef.Raylib.GetScreenWidth();
	public static int32 SCREEN_HEIGHT => RaylibBeef.Raylib.GetScreenHeight();

	public static float SCREEN_ASPECT_RATIO => (float)SCREEN_WIDTH / (float)SCREEN_HEIGHT;
#else

#if BF_PLATFORM_WASM
	public const int32 BASE_SCREEN_WIDTH = 1280;
	public const int32 BASE_SCREEN_HEIGHT = 720;
#else
	public const int32 BASE_SCREEN_WIDTH = 1280;
	public const int32 BASE_SCREEN_HEIGHT = 720;
#endif

	public static int32 SCREEN_WIDTH = BASE_SCREEN_WIDTH;
	public static int32 SCREEN_HEIGHT = BASE_SCREEN_HEIGHT;

	public static float SCREEN_ASPECT_RATIO => (float)BASE_SCREEN_WIDTH / (float)BASE_SCREEN_HEIGHT;
#endif

	public static Version GameVerison = .(1, 0, 0);
}