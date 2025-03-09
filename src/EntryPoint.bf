using System;
using RaylibBeef;

namespace Minesweeper;

class EntryPoint
{
	#if BF_PLATFORM_WASM
	[CLink, CallingConvention(.Stdcall)]
	private static extern void emscripten_console_log(char8* utf8String);

	private function void em_callback_func();

	[CLink, CallingConvention(.Stdcall)]
	private static extern void emscripten_set_main_loop(em_callback_func func, int32 fps, int32 simulateInfinteLoop);

	[CLink, CallingConvention(.Stdcall)]
	private static extern int32 emscripten_set_main_loop_timing(int32 mode, int32 value);

	[CLink, CallingConvention(.Stdcall)]
	private static extern double emscripten_get_now();

	private static void emscriptenMainLoop()
	{
		Loop(s_Game, s_ScreenTexture);
	}
#endif

	private static Game s_Game;
	private static RenderTexture s_ScreenTexture;

	private static Vector2 s_MousePositionViewport = .Zero;
	private static Vector2 s_ViewportSize = .Zero;
	private static int s_ViewportScale = 1;

	public static Vector2 MousePositionViewport => s_MousePositionViewport;
	public static Vector2 ViewportSize => s_ViewportSize;
	public static int ViewportScale => s_ViewportScale;

	public static void Start(String[] args)
	{
		Raylib.SetConfigFlags(.FLAG_VSYNC_HINT | .FLAG_WINDOW_RESIZABLE);
		Raylib.InitWindow(1280, 720, "Minesweeper+");
		Raylib.InitAudioDevice();

		s_ScreenTexture = Raylib.LoadRenderTexture(SCREEN_WIDTH, SCREEN_HEIGHT);

		InitAssets();
		s_Game = scope Game();

#if BF_PLATFORM_WASM
		emscripten_set_main_loop(=> emscriptenMainLoop, 0, 1);
#else
		while (!Raylib.WindowShouldClose())
		{
			Loop(s_Game, s_ScreenTexture);
		}
#endif

		Raylib.UnloadRenderTexture(s_ScreenTexture);

		DestroyAssets();

		Raylib.CloseAudioDevice();
		Raylib.CloseWindow();
	}

	private static void Loop(Game game, RenderTexture screenTexture)
	{
		game.Update();

		Raylib.BeginDrawing();
		Raylib.BeginTextureMode(screenTexture);

		game.Render();

		Raylib.EndTextureMode();

		// Draw screen
		let viewportSize = getLargestSizeForViewport();
		let viewportPos = getCenteredPositionForViewport(viewportSize);

		let relativeMouseX = Raylib.GetMouseX() - viewportPos.x;
		let relativeMouseY = Raylib.GetMouseY() - viewportPos.y;
		s_MousePositionViewport = .((relativeMouseX / viewportSize.x) * SCREEN_WIDTH, (relativeMouseY / viewportSize.y) * SCREEN_HEIGHT);
		s_MousePositionViewport = .(Math.Clamp(s_MousePositionViewport.x, 0, SCREEN_WIDTH), Math.Clamp(s_MousePositionViewport.y, 0, SCREEN_HEIGHT));

		s_ViewportSize = viewportSize;
		s_ViewportScale =(int)(viewportSize.x / SCREEN_WIDTH);

		Raylib.DrawTexturePro(screenTexture.texture,
			.(0, 0, screenTexture.texture.width, -screenTexture.texture.height),
			.(viewportPos.x, viewportPos.y, viewportSize.x, viewportSize.y),
			.(0, 0),
			0,
			Raylib.WHITE);

		Raylib.EndDrawing();
	}

	private static Vector2 getLargestSizeForViewport()
	{
	    let windowSize = Vector2(Raylib.GetScreenWidth(), Raylib.GetScreenHeight());

	    float aspectWidth = windowSize.x;
	    float aspectHeight = aspectWidth / SCREEN_ASPECT_RATIO;
	    if (aspectHeight > windowSize.y)
	    {
	        aspectHeight = windowSize.y;
	        aspectWidth = aspectHeight * SCREEN_ASPECT_RATIO;
	    }

		return .(Math.Round2Nearest(aspectWidth, SCREEN_WIDTH), Math.Round2Nearest(aspectHeight, SCREEN_HEIGHT));
	}

	private static Vector2 getCenteredPositionForViewport(Vector2 aspectSize)
	{
		let windowSize = Vector2(Raylib.GetScreenWidth(), Raylib.GetScreenHeight());

	    float viewportX = (windowSize.x / 2.0f) - (aspectSize.x / 2.0f);
	    float viewportY = (windowSize.y / 2.0f) - (aspectSize.y / 2.0f);

	    return .(viewportX, viewportY);
	}
}