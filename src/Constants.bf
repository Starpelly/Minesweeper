using RaylibBeef;

namespace Minesweeper;

static
{
#if GAME_SCREEN_CONSTANT
	public const int SCREEN_WIDTH = 320 * 2;
	public const int SCREEN_HEIGHT = 180 * 2;

	public const float SCREEN_ASPECT_RATIO = (float)SCREEN_WIDTH / (float)SCREEN_HEIGHT;
#elif GAME_SCREEN_FREE
	public static int32 SCREEN_WIDTH => Raylib.GetScreenWidth();
	public static int32 SCREEN_HEIGHT => Raylib.GetScreenHeight();

	public static float SCREEN_ASPECT_RATIO => (float)SCREEN_WIDTH / (float)SCREEN_HEIGHT;
#else
	public const int32 BASE_SCREEN_WIDTH = 1280;
	public const int32 BASE_SCREEN_HEIGHT = 720;

	public static int32 SCREEN_WIDTH = 1280;
	public static int32 SCREEN_HEIGHT = 720;

	public static float SCREEN_ASPECT_RATIO => (float)SCREEN_WIDTH / (float)SCREEN_HEIGHT;
#endif
}