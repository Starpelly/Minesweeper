using System;
using RaylibBeef;
namespace Minesweeper;

public static struct Data
{
	public static struct Textures
	{
		public static uint8[?] Flags = Compiler.ReadBinary("assets/sprites/flags.png");
		public static uint8[?] Tiles = Compiler.ReadBinary("assets/sprites/tiles.png");
		public static uint8[?] Frame = Compiler.ReadBinary("assets/sprites/frame.png");
		public static uint8[?] Bomb = Compiler.ReadBinary("assets/sprites/bomb.png");
		public static uint8[?] Heart = Compiler.ReadBinary("assets/sprites/heart.png");
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
		// public static uint8[?] GameOver = Compiler.ReadBinary("assets/sounds/gameover.wav");
	}

	public static struct Fonts
	{
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

		public this(uint8* data, int32 dataCount, int32 fontSize)
		{
			Font = Raylib.LoadFontFromMemory(".ttf", (char8*)data, dataCount, 32, null, 0);
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

	public class Textures
	{
		public readonly TextureEx Flags = new .(&Data.Textures.Flags, Data.Textures.Flags.Count) ~ delete _;
		public readonly TextureEx Tiles = new .(&Data.Textures.Tiles, Data.Textures.Tiles.Count) ~ delete _;
		public readonly TextureEx Frame = new .(&Data.Textures.Frame, Data.Textures.Frame.Count) ~ delete _;
		public readonly TextureEx Bomb = new .(&Data.Textures.Bomb, Data.Textures.Bomb.Count) ~ delete _;
		public readonly TextureEx Heart = new .(&Data.Textures.Heart, Data.Textures.Heart.Count) ~ delete _;
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
		// public readonly SoundFX GameOver = new .(&Data.Sounds.GameOver, Data.Sounds.GameOver.Count) ~ delete _;
	}

	public class Fonts
	{
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