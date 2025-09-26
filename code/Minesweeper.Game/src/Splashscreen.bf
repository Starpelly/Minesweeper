using RaylibBeef;
using System;
namespace Minesweeper;

[Reflect(.DefaultConstructor), AlwaysInclude(AssumeInstantiated=true)]
class Splashscreen : Scene
{
	// ---------
	// Constants
	// ---------

	private const float SPLASHSCREEN_LENGTH = 2.25f;
	private const float SPLASHSCREEN_DELAY =
#if BF_PLATFORM_WASM
		0.25f; // Browsers are slower
#else
		0.1f;
#endif
	private const float SCREEN_FADE_LENGTH = 0.15f;

	// -----------------
	// Private variables
	// -----------------

	private float m_SceneTime = 0.0f;
	private bool m_Initialized = false;

	// --------------
	// Public methods
	// --------------

	public this()
	{
		m_SceneTime -= SPLASHSCREEN_DELAY;
	}

	// ------
	// Events
	// ------

	public override void Update()
	{
		m_SceneTime += Raylib.GetFrameTime();

		if (m_SceneTime >= SPLASHSCREEN_DELAY && !m_Initialized)
		{
			Raylib.PlaySound(Assets.Sounds.Splashscreen.Sound);
			m_Initialized = true;
		}
		if (m_SceneTime >= SPLASHSCREEN_LENGTH)
		{
			EntryPoint.SetScene<Game>();
		}
	}

	public override void Render()
	{
		if (m_SceneTime <= SPLASHSCREEN_DELAY)
			return;

		Camera2D cam = .(.Zero, .(-BASE_SCREEN_WIDTH / 2, -BASE_SCREEN_HEIGHT / 2), 0, ((float)SCREEN_WIDTH / (float)BASE_SCREEN_WIDTH));

		Raylib.BeginMode2D(cam);
		{
			Raylib.ClearBackground(.ScreenFade);

			let logoTexture = Assets.Textures.Boxsubmus.Texture;
			let logoScale = 0.55f;
			let logoSize = Vector2(logoTexture.width, logoTexture.height);

			var logoScaleInfluence = 1.0f;

			// Bounce in
			{
				// let length = 1f;
				// let offset = SPLASHSCREEN_DELAY;

				// let time = Math.Clamp(m_SceneTime, offset, offset + length);
				// let ease = EasingFunctions.OutElastic(Math.Normalize(time, offset, offset + length), 0.56f);

				// logoScaleInfluence = Math.Lerp(0.0f, 1.0f, ease);
			}

			// Draw the logo
			{
				let drawScale = logoScale * logoScaleInfluence;
				let drawSize = logoSize * drawScale;
				let drawPosMiddle = Vector2(-drawSize.x / 2, -drawSize.y / 2);

				Raylib.DrawTextureEx(logoTexture, .(drawPosMiddle.x, drawPosMiddle.y), 0, drawScale, .White);
			}
		}
		Raylib.EndMode2D();

		// Screen fade
		// if (m_SceneTime >= SPLASHSCREEN_LENGTH - SCREEN_FADE_LENGTH)
			Raylib.DrawRectangle(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT,
				.(Color.ScreenFade.r, Color.ScreenFade.g, Color.ScreenFade.b,
				(uint8)Math.Lerp(0, 255, Math.Normalize((m_SceneTime) - (SPLASHSCREEN_LENGTH - SCREEN_FADE_LENGTH), 0, SCREEN_FADE_LENGTH, true))));
	}
}