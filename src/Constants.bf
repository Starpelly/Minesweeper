using System;
namespace Minesweeper;

static
{
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

	public const Version GameVerison = .(1, 0, 2);
}