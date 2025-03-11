using System;
using RaylibBeef;

namespace Minesweeper;

class EntryPoint
{
	private const bool VIEWPORT_USE_RENDERTEXTURE = false;

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
		Loop(s_Game);
	}
#endif

	private static Game s_Game;

#if !GAME_SCREEN_FREE
	private static RenderTexture s_ScreenTexture;
#endif

	private static Vector2 s_MousePositionViewport = .Zero;
	private static Vector2 s_ViewportSize = .Zero;
	private static int s_ViewportScale = 1;

	public static Vector2 MousePositionViewport => s_MousePositionViewport;
	public static Vector2 ViewportSize => s_ViewportSize;
	public static int ViewportScale => s_ViewportScale;

	private static Vector2 s_LastViewportSize = .(0, 0);

	public static void Start(String[] args)
	{
		ConfigFlags flags = .FLAG_VSYNC_HINT | .FLAG_WINDOW_RESIZABLE;
#if GAME_SCREEN_FREE
#endif
		flags |= .FLAG_MSAA_4X_HINT;

		Raylib.SetConfigFlags(flags);
		Raylib.InitWindow(BASE_SCREEN_WIDTH, BASE_SCREEN_HEIGHT, "Minesweeper+");
		Raylib.InitAudioDevice();

		SCREEN_WIDTH = Raylib.GetScreenWidth();
		SCREEN_HEIGHT = Raylib.GetScreenHeight();

#if !GAME_SCREEN_FREE
#if GAME_SCREEN_CONSTANT
		s_ScreenTexture = Raylib.LoadRenderTexture(SCREEN_WIDTH, SCREEN_HEIGHT);
#else
		if (VIEWPORT_USE_RENDERTEXTURE)
		{
			s_ScreenTexture = Raylib.LoadRenderTexture(SCREEN_WIDTH, SCREEN_HEIGHT);
			s_LastViewportSize = .(SCREEN_WIDTH, SCREEN_HEIGHT);
		}
#endif
#endif

		InitAssets();
		s_Game = scope Game();

#if BF_PLATFORM_WASM
		emscripten_set_main_loop(=> emscriptenMainLoop, 0, 1);
#else
		while (!Raylib.WindowShouldClose())
		{
			Loop(s_Game);
		}
#endif

#if !GAME_SCREEN_FREE
		Raylib.UnloadRenderTexture(s_ScreenTexture);
#endif

		DestroyAssets();

		Raylib.CloseAudioDevice();
		Raylib.CloseWindow();
	}

	private static void Loop(Game game)
	{
		let viewportSize = getLargestSizeForViewport();
		let viewportPos = getCenteredPositionForViewport(viewportSize);

		s_ViewportSize = viewportSize;
		s_ViewportScale =(int)(viewportSize.x / SCREEN_WIDTH);

		if (s_ViewportSize != s_LastViewportSize)
		{
			if (VIEWPORT_USE_RENDERTEXTURE)
			{
				Raylib.UnloadRenderTexture(s_ScreenTexture);
				s_ScreenTexture = Raylib.LoadRenderTexture((int32)s_ViewportSize.x, (int32)s_ViewportSize.y);
			}

			SCREEN_WIDTH = (int32)s_ViewportSize.x;
			SCREEN_HEIGHT = (int32)s_ViewportSize.y;
		}
		s_LastViewportSize = s_ViewportSize;

		let relativeMouseX = Raylib.GetMouseX() - viewportPos.x;
		let relativeMouseY = Raylib.GetMouseY() - viewportPos.y;
		s_MousePositionViewport = .((relativeMouseX / viewportSize.x) * SCREEN_WIDTH, (relativeMouseY / viewportSize.y) * SCREEN_HEIGHT);
		s_MousePositionViewport = .(Math.Clamp(s_MousePositionViewport.x, 0, SCREEN_WIDTH), Math.Clamp(s_MousePositionViewport.y, 0, SCREEN_HEIGHT));

		game.Update();

		Raylib.BeginDrawing();

		game.RenderUI();

#if !GAME_SCREEN_FREE

		if (VIEWPORT_USE_RENDERTEXTURE)
		{
			Raylib.BeginTextureMode(s_ScreenTexture);
		}
		else
		{
			Raylib.BeginScissorMode((int32)viewportPos.x, (int32)viewportPos.y, (int32)viewportSize.x, (int32)viewportSize.y);
			Rlgl.rlViewport((int32)(viewportPos.x), -(int32)(viewportPos.y), Raylib.GetScreenWidth(), Raylib.GetScreenHeight());
		}
#endif

		game.Render();

#if !GAME_SCREEN_FREE

		if (VIEWPORT_USE_RENDERTEXTURE)
		{
			Raylib.EndTextureMode();
		}
		else
		{
			Raylib.EndScissorMode();
			Rlgl.rlViewport(0, 0, Raylib.GetScreenWidth(), Raylib.GetScreenHeight());
		}

		// Draw screen
		/*
		Raylib.DrawTexturePro(s_ScreenTexture.texture,
			.(0, 0, s_ScreenTexture.texture.width, -s_ScreenTexture.texture.height),
			.(viewportPos.x, viewportPos.y, viewportSize.x, viewportSize.y),
			.(0, 0),
			0,
			Raylib.WHITE);
		*/
#endif

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

#if GAME_SCREEN_CONSTANT
		return .(Math.Round2Nearest(aspectWidth, SCREEN_WIDTH), Math.Round2Nearest(aspectHeight, SCREEN_HEIGHT));
#else
		return .(aspectWidth, aspectHeight);
#endif
	}

	private static Vector2 getCenteredPositionForViewport(Vector2 aspectSize)
	{
		let windowSize = Vector2(Raylib.GetScreenWidth(), Raylib.GetScreenHeight());

		float viewportX = (windowSize.x / 2.0f) - (aspectSize.x / 2.0f);
		float viewportY = (windowSize.y / 2.0f) - (aspectSize.y / 2.0f);

		return .(viewportX, viewportY);
	}
}