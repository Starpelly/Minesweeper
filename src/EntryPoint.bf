using System;
using RaylibBeef;

namespace Minesweeper;

class EntryPoint
{
	private const bool VIEWPORT_USE_RENDERTEXTURE = false;

	private enum SceneType
	{
		Null,
		Splashscreen,
		Game
	}

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
		let test = true;

		if (test)
		{
			Loop();
		}
		else
		{
			Raylib.BeginDrawing();
			Raylib.ClearBackground(.Red);
			Raylib.EndDrawing();
		}
	}
#endif

	private Scene s_CurrentScene ~ delete _;
	private SceneType s_SceneToSwapTo = .Null;
	private bool s_SwappingScene = false;

#if !GAME_SCREEN_FREE
	private RenderTexture s_ScreenTexture;
#endif

	private Vector2 m_MousePositionViewport = .Zero;
	private Vector2 m_ViewportSize = .Zero;
	private int m_ViewportScale = 1;

	public int ViewportScale => m_ViewportScale;

	private Vector2 s_LastViewportSize = .(0, 0);

	private static EntryPoint Instance { get; private set; }

	public static void SetScene<T>() where T : Scene
	{
		Instance.s_SwappingScene = true;
		if (typeof(T) == typeof(Splashscreen))
			Instance.s_SceneToSwapTo = .Splashscreen;
		else if (typeof(T) == typeof(Game))
			Instance.s_SceneToSwapTo = .Game;
	}

	public this()
	{
		Instance = this;
	}

	public static Vector2 GetMousePositionViewport()
	{
		return Instance.m_MousePositionViewport;
	}

	public static int GetViewportScale()
	{
		return Instance.ViewportScale;
	}

	public void Start(String[] args)
	{
		ConfigFlags flags = .FLAG_VSYNC_HINT;
		flags |= .FLAG_MSAA_4X_HINT;

#if BF_PLATFORM_ANDROID
		Raylib.SetConfigFlags(flags);
		Raylib.InitWindow(0, 0, "Minesweeper+");
#else
		flags |= .FLAG_WINDOW_RESIZABLE;

		Raylib.SetConfigFlags(flags);
		Raylib.InitWindow(BASE_SCREEN_WIDTH, BASE_SCREEN_HEIGHT, "Minesweeper+");
#endif

		// Load window icon
		{
			let iconPng = Raylib.LoadImageFromMemory(".png", (char8*)&Data.WindowIcon, Data.WindowIcon.Count);
			Raylib.SetWindowIcon(iconPng);
			Raylib.UnloadImage(iconPng);

		}
		Raylib.InitAudioDevice();

		Raylib.SetExitKey(.KEY_NULL);

		SCREEN_WIDTH = BASE_SCREEN_WIDTH;
		SCREEN_HEIGHT = BASE_SCREEN_HEIGHT;

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

#if DEBUG && !BF_PLATFORM_ANDROID
		SetScene<Game>();
#else
		SetScene<Splashscreen>();
#endif
		// s_CurrentScene = scope Game();

#if BF_PLATFORM_WASM
		emscripten_set_main_loop(=> emscriptenMainLoop, 0, 1);
#else
		while (!Raylib.WindowShouldClose())
		{
			Loop();
		}
#endif

#if !GAME_SCREEN_FREE
		Raylib.UnloadRenderTexture(s_ScreenTexture);
#endif

		DestroyAssets();

		Raylib.CloseAudioDevice();
		Raylib.CloseWindow();
	}

	private void Loop()
	{
		// Swap scene
		if (s_SwappingScene == true)
		{
			if (s_CurrentScene != null)
				delete s_CurrentScene;

			// let obj = s_SceneToSwapTo.CreateObject();
			// s_CurrentScene = (Scene)obj;

			switch (s_SceneToSwapTo)
			{
			case .Game: s_CurrentScene = new Game(); break;
			case .Splashscreen: s_CurrentScene = new Splashscreen(); break;
			case .Null: /* Idk??? */ break;
			}

			s_SceneToSwapTo = .Null;
			s_SwappingScene = false;
		}

		let viewportSize = getLargestSizeForViewport();
		let viewportPos = getCenteredPositionForViewport(viewportSize);

		m_ViewportSize = viewportSize;
		m_ViewportScale =(int)(viewportSize.x / SCREEN_WIDTH);

		if (m_ViewportSize != s_LastViewportSize)
		{
			if (VIEWPORT_USE_RENDERTEXTURE)
			{
				Raylib.UnloadRenderTexture(s_ScreenTexture);
				s_ScreenTexture = Raylib.LoadRenderTexture((int32)viewportSize.x, (int32)viewportSize.y);
			}

			SCREEN_WIDTH = (int32)m_ViewportSize.x;
			SCREEN_HEIGHT = (int32)m_ViewportSize.y;
		}
		s_LastViewportSize = m_ViewportSize;

		let relativeMouseX = Raylib.GetMouseX() - viewportPos.x;
		let relativeMouseY = Raylib.GetMouseY() - viewportPos.y;

		m_MousePositionViewport = .((relativeMouseX / viewportSize.x), (relativeMouseY / viewportSize.y) );
		m_MousePositionViewport = .(Math.Clamp(m_MousePositionViewport.x, 0, 1), Math.Clamp(m_MousePositionViewport.y, 0, 1));

		s_CurrentScene.Update();

		Raylib.BeginDrawing();

		Raylib.ClearBackground(.Black);

		if (let game = s_CurrentScene as Game)
		{
			game.RenderUIToTexture();
			game.RenderOverlayToTexture();
		}
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

		s_CurrentScene.Render();

		// Render cursor
#if !BF_PLATFORM_ANDROID
		Raylib.HideCursor();
		Raylib.DrawTexturePro(Assets.Textures.Cursors.Texture,
			.(239, 103, 14, 15),
			.(Raylib.GetMousePosition().x, Raylib.GetMousePosition().y, 14 * 2, 15 * 2),
			.Zero,
			0,
			.White);
#endif

#if DEBUG
		Text.DrawTextColored(scope $"{Raylib.GetFPS()} FPS", .(20, 20), .Big, .Outline, .Green);
		Text.DrawTextColored("Running Debug Configuration", .(20, 40), .Big, .Outline, .Green);

#if BF_PLATFORM_ANDROID
		let platform = "Android";
#elif BF_PLATFORM_WASM
		let platform = "Wasm";
#elif BF_PLATFORM_WINDOWS
		let platform = "Windows";
#endif
		Text.DrawTextColored(scope $"Platform: {platform}", .(20, 60), .Big, .Outline, .Green);
#endif

#if !GAME_SCREEN_FREE
		if (VIEWPORT_USE_RENDERTEXTURE)
		{
			Raylib.EndTextureMode();

			// Raylib.BeginShaderMode(Assets.Shaders.Grayscale.Shader);
			Raylib.DrawTexturePro(s_ScreenTexture.texture,
				.(0, 0, s_ScreenTexture.texture.width, -s_ScreenTexture.texture.height),
				.(viewportPos.x, viewportPos.y, viewportSize.x, viewportSize.y),
				.(0, 0),
				0,
				Raylib.WHITE);
			// Raylib.EndShaderMode();
		}
		else
		{
			Raylib.EndScissorMode();
			Rlgl.rlViewport(0, 0, Raylib.GetScreenWidth(), Raylib.GetScreenHeight());
		}
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