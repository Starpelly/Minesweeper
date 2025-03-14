using System;
using RaylibBeef;
namespace Minesweeper;

public static struct Data
{
	public static uint8[?] WindowIcon = Compiler.ReadBinary("assets/icon.png");

	public static struct Textures
	{
		public static uint8[?] Flags = Compiler.ReadBinary("assets/sprites/flags.png");
		public static uint8[?] Tiles = Compiler.ReadBinary("assets/sprites/tiles.png");
		public static uint8[?] Frame = Compiler.ReadBinary("assets/sprites/frame.png");
		public static uint8[?] Bomb = Compiler.ReadBinary("assets/sprites/bomb.png");
		public static uint8[?] Heart = Compiler.ReadBinary("assets/sprites/heart.png");
		public static uint8[?] Boxsubmus = Compiler.ReadBinary("assets/sprites/boxsubmus.png");
		public static uint8[?] Cloud = Compiler.ReadBinary("assets/sprites/cloud.png");
		public static uint8[?] Logo = Compiler.ReadBinary("assets/sprites/logo.png");

		public static uint8[?] Logo_0 = Compiler.ReadBinary("assets/sprites/logo_char_1.png");
		public static uint8[?] Logo_1 = Compiler.ReadBinary("assets/sprites/logo_char_2.png");
		public static uint8[?] Logo_2 = Compiler.ReadBinary("assets/sprites/logo_char_3.png");
		public static uint8[?] Logo_3 = Compiler.ReadBinary("assets/sprites/logo_char_4.png");
		public static uint8[?] Logo_4 = Compiler.ReadBinary("assets/sprites/logo_char_5.png");
		public static uint8[?] Logo_5 = Compiler.ReadBinary("assets/sprites/logo_char_6.png");
		public static uint8[?] Logo_6 = Compiler.ReadBinary("assets/sprites/logo_char_7.png");
		public static uint8[?] Logo_7 = Compiler.ReadBinary("assets/sprites/logo_char_8.png");
		public static uint8[?] Logo_8 = Compiler.ReadBinary("assets/sprites/logo_char_9.png");
		public static uint8[?] Logo_9 = Compiler.ReadBinary("assets/sprites/logo_char_10.png");
		public static uint8[?] Logo_10 = Compiler.ReadBinary("assets/sprites/logo_char_11.png");
		public static uint8[?] Logo_11 = Compiler.ReadBinary("assets/sprites/logo_char_12.png");
	}

	public static struct Sounds
	{
		public static uint8[?] Click = Compiler.ReadBinary("assets/sounds/click.wav");
		public static uint8[?] Flag = Compiler.ReadBinary("assets/sounds/flag.wav");
		public static uint8[?] Boom = Compiler.ReadBinary("assets/sounds/boom.wav");
		public static uint8[?] Tap = Compiler.ReadBinary("assets/sounds/tap.wav");
		public static uint8[?] Win = Compiler.ReadBinary("assets/sounds/win.wav");
		public static uint8[?] ClearArea = Compiler.ReadBinary("assets/sounds/clear-area.wav");
		public static uint8[?] FailedChord = Compiler.ReadBinary("assets/sounds/failed-chord.wav");
		public static uint8[?] Hover = Compiler.ReadBinary("assets/sounds/hover.wav");
		public static uint8[?] Splashscreen = Compiler.ReadBinary("assets/sounds/boxsubmus-splash.wav");
		public static uint8[?] StartGame = Compiler.ReadBinary("assets/sounds/startgame.wav");
		public static uint8[?] LoseTransition = Compiler.ReadBinary("assets/sounds/lose-transition.wav");
		public static uint8[?] Restart = Compiler.ReadBinary("assets/sounds/restart.wav");
	}

	public static struct Fonts
	{
		public static uint8[?] NokiaAtlas = Compiler.ReadBinary("assets/fonts/nokia.png");
		public static uint8[?] NokiaOutlineAtlas = Compiler.ReadBinary("assets/fonts/nokia_outline.png");
	}
}

public class AssetManager
{
	public class TextureEx
	{
		public Image Image { get; private set; }
		public Texture2D Texture { get; private set; }
		public Color* Pixels { get; private set; }

		public this(uint8* pixels, int32 count, TextureFilter filter = .TEXTURE_FILTER_POINT)
		{
			Image = Raylib.LoadImageFromMemory(".png", (char8*)pixels, count);
			Texture = Raylib.LoadTextureFromImage(Image);
			Raylib.SetTextureFilter(Texture, filter);
			Pixels = Raylib.LoadImageColors(Image);
		}

		public ~this()
		{
			Raylib.UnloadImage(Image);
			Raylib.UnloadTexture(Texture);
			Raylib.UnloadImageColors(Pixels);
		}

		public Vector2 Size()
		{
			return .(Texture.width, Texture.height);
		}
	}

	public class SoundFX
	{
		public Sound Sound { get; private set; }

		public this(uint8* samples, int32 sampleCount)
		{
			let wave = Raylib.LoadWaveFromMemory(".wav", (char8*)samples, sampleCount);
			Sound = Raylib.LoadSoundFromWave(wave);
			Raylib.UnloadWave(wave);
		}

		public ~this()
		{
			Raylib.UnloadSound(Sound);
		}
	}

	public class FontEx
	{
		public Font Font { get; private set; }

		public this(uint8* data, int32 dataCount, int32 fontSize, bool bitmap)
		{
			if (bitmap)
			{
				loadBitmapFont(data, dataCount);
			}
			else
			{
				Font = Raylib.LoadFontFromMemory(".ttf", (char8*)data, dataCount, 32, null, 0);
			}
		}

		public ~this()
		{
			Raylib.UnloadFont(Font);
		}

		private void loadBitmapFont(uint8* data, int32 dataCount)
		{
			let img = Raylib.LoadImageFromMemory(".png", (char8*)data, dataCount);

			Font = Raylib.LoadFontFromImage(img, .(255, 0, 255, 255), 32);

			Raylib.UnloadImage(img);
		}
	}

	public class Shader
	{
		public RaylibBeef.Shader Shader { get; private set; }

		public this(String vertexCode, String fragmentCode)
		{
			Shader = Raylib.LoadShaderFromMemory(vertexCode, fragmentCode);
		}

		public ~this()
		{
			Raylib.UnloadShader(Shader);
		}
	}

	public class Textures
	{
		public readonly TextureEx Flags = new .(&Data.Textures.Flags, Data.Textures.Flags.Count) ~ delete _;
		public readonly TextureEx Tiles = new .(&Data.Textures.Tiles, Data.Textures.Tiles.Count) ~ delete _;
		public readonly TextureEx Frame = new .(&Data.Textures.Frame, Data.Textures.Frame.Count) ~ delete _;
		public readonly TextureEx Bomb = new .(&Data.Textures.Bomb, Data.Textures.Bomb.Count) ~ delete _;
		public readonly TextureEx Heart = new .(&Data.Textures.Heart, Data.Textures.Heart.Count) ~ delete _;
		public readonly TextureEx Boxsubmus = new .(&Data.Textures.Boxsubmus, Data.Textures.Boxsubmus.Count, .TEXTURE_FILTER_BILINEAR) ~ delete _;
		public readonly TextureEx Cloud = new .(&Data.Textures.Cloud, Data.Textures.Cloud.Count) ~ delete _;
		public readonly TextureEx Logo = new .(&Data.Textures.Logo, Data.Textures.Logo.Count) ~ delete _;

		public readonly TextureEx Logo_Char_0 = new .(&Data.Textures.Logo_0, Data.Textures.Logo_0.Count) ~ delete _;
		public readonly TextureEx Logo_Char_1 = new .(&Data.Textures.Logo_1, Data.Textures.Logo_1.Count) ~ delete _;
		public readonly TextureEx Logo_Char_2 = new .(&Data.Textures.Logo_2, Data.Textures.Logo_2.Count) ~ delete _;
		public readonly TextureEx Logo_Char_3 = new .(&Data.Textures.Logo_3, Data.Textures.Logo_3.Count) ~ delete _;
		public readonly TextureEx Logo_Char_4 = new .(&Data.Textures.Logo_4, Data.Textures.Logo_4.Count) ~ delete _;
		public readonly TextureEx Logo_Char_5 = new .(&Data.Textures.Logo_5, Data.Textures.Logo_5.Count) ~ delete _;
		public readonly TextureEx Logo_Char_6 = new .(&Data.Textures.Logo_6, Data.Textures.Logo_6.Count) ~ delete _;
		public readonly TextureEx Logo_Char_7 = new .(&Data.Textures.Logo_7, Data.Textures.Logo_7.Count) ~ delete _;
		public readonly TextureEx Logo_Char_8 = new .(&Data.Textures.Logo_8, Data.Textures.Logo_8.Count) ~ delete _;
		public readonly TextureEx Logo_Char_9 = new .(&Data.Textures.Logo_9, Data.Textures.Logo_9.Count) ~ delete _;
		public readonly TextureEx Logo_Char_10 = new .(&Data.Textures.Logo_10, Data.Textures.Logo_10.Count) ~ delete _;
		public readonly TextureEx Logo_Char_11 = new .(&Data.Textures.Logo_11, Data.Textures.Logo_11.Count) ~ delete _;
	}

	public class Sounds
	{
		public readonly SoundFX Click = new .(&Data.Sounds.Click, Data.Sounds.Click.Count) ~ delete _;
		public readonly SoundFX Flag = new .(&Data.Sounds.Flag, Data.Sounds.Flag.Count) ~ delete _;
		public readonly SoundFX Boom = new .(&Data.Sounds.Boom, Data.Sounds.Boom.Count) ~ delete _;
		public readonly SoundFX Tap = new .(&Data.Sounds.Tap, Data.Sounds.Tap.Count) ~ delete _;
		public readonly SoundFX Win = new .(&Data.Sounds.Win, Data.Sounds.Win.Count) ~ delete _;
		public readonly SoundFX ClearArea = new .(&Data.Sounds.ClearArea, Data.Sounds.ClearArea.Count) ~ delete _;
		public readonly SoundFX FailedChord = new .(&Data.Sounds.FailedChord, Data.Sounds.FailedChord.Count) ~ delete _;
		public readonly SoundFX Hover = new .(&Data.Sounds.Hover, Data.Sounds.Hover.Count) ~ delete _;
		public readonly SoundFX Splashscreen = new .(&Data.Sounds.Splashscreen, Data.Sounds.Splashscreen.Count) ~ delete _;
		public readonly SoundFX StartGame = new .(&Data.Sounds.StartGame, Data.Sounds.StartGame.Count) ~ delete _;
		public readonly SoundFX LoseTransition = new .(&Data.Sounds.LoseTransition, Data.Sounds.LoseTransition.Count) ~ delete _;
		public readonly SoundFX Restart = new .(&Data.Sounds.Restart, Data.Sounds.Restart.Count) ~ delete _;
	}

	public class Fonts
	{
		public readonly FontEx Nokia = new .(&Data.Fonts.NokiaAtlas, Data.Fonts.NokiaAtlas.Count, 20, true) ~ delete _;
		public readonly FontEx NokiaOutline = new .(&Data.Fonts.NokiaOutlineAtlas, Data.Fonts.NokiaOutlineAtlas.Count, 20, true) ~ delete _;
	}

	public Textures Textures = new .() ~ delete _;
	public Sounds Sounds = new .() ~ delete _;
	public Fonts Fonts = new .() ~ delete _;

	public this()
	{
		// empty
	}
}

static
{
	public static AssetManager Assets;

	public static void InitAssets()
	{
		Assets = new .();
	}

	public static void DestroyAssets()
	{
		delete Assets;
	}
}