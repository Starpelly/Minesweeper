using System;
using RaylibBeef;

namespace Minesweeper;

class Particle
{
	private Game m_Game;
	private bool m_PendingDeletion = false;

	internal void SetGame(Game game)
	{
		m_Game = game;
	}

	public virtual void Update()
	{
	}

	public virtual void Render()
	{
	}

	public void DestroySelf()
	{
		m_Game.RemoveParticle(this);
		m_PendingDeletion = true;
	}
}

class OpenedTileParticle : Particle
{
	private Vector2 m_Position;
	private float m_Scale = 1.0f;
	private float m_Angle = 0.0f;
	private float m_AngleOffset = 0.0f;

	private Color m_TileColor;

	private Vector2 m_Velocity = .Zero;
	private float gravity = 3.1f;
	private float m_Opacity = 1.0f;

	public this(Vector2 position, Color color)
	{
		m_Position = position;
		m_TileColor = color;

		gravity = Math.RandomFloat32(10.5f, 16.3f) * 64;
		m_Velocity.x = (Game.Random.Next(0, 2) == 0 ? -1 : 1) * Math.RandomFloat32(48, 85);
		m_Velocity.y = Math.RandomFloat32(-260, -210);
	}

	public override void Update()
	{
		m_Velocity += .(0, gravity) * Raylib.GetFrameTime();

		m_Position += m_Velocity * Raylib.GetFrameTime();

		// Rotation = Math.Atan2(m_Velocity.y, m_Velocity.x) * (180.0f / Math.PI_f);
		m_AngleOffset += (m_Velocity.x * 10) * Raylib.GetFrameTime();

		m_Scale -= 1.3f * Raylib.GetFrameTime();

		m_Opacity -= 2.0f * Raylib.GetFrameTime();

		if (m_Scale < 0.0f || m_Opacity <= 0.0f)
			DestroySelf();
	}

	public override void Render()
	{
		let color = Color(m_TileColor.r, m_TileColor.g, m_TileColor.b, (uint8)(m_Opacity * 255.0f));
		// Raylib.DrawRectanglePro(.(Position.x, Position.y + 12, 18, 18), .(9, 9), Rotation, .(0, 0, 0, 50));
		Raylib.DrawTexturePro(Assets.Textures.Tiles.Texture, .(0, 0, 18, 18), .(m_Position.x + 8, m_Position.y + 8, 18 * m_Scale, 18 * m_Scale), Vector2(9, 9) * m_Scale, m_Angle + m_AngleOffset, color);
	}
}

class ExplosionFlashParticle : Particle
{
	private float m_Time;
	private float m_StartAlpha = 0.0f;

	public this(float startAlpha)
	{
		m_Time = 0.7f;
		m_StartAlpha = startAlpha;
	}

	public override void Update()
	{
		m_Time -= Raylib.GetFrameTime();
		if (m_Time <= 0.0f)
			DestroySelf();
	}

	public override void Render()
	{
		Raylib.DrawRectangle(-10000, -10000, 100000, 100000, .(255, 0, 0, (uint8)(m_Time * m_StartAlpha)));
	}
}

class NewPointsParticle : Particle
{
	private Vector2 m_Position;
	private Color m_Color;

	private String m_Text = new .() ~ delete _;

	private float m_Time = 0.0f;
	private Color m_DrawColor;

	public this(Vector2 position, Color color, String text)
	{
		m_Position = position;
		m_Color = color;
		m_Text.Append(text);
	}

	public override void Update()
	{
		m_Time += Raylib.GetFrameTime();
		m_Position.y -= 30 * Raylib.GetFrameTime();

		if (m_Time >= 1.0f)
			DestroySelf();

		m_DrawColor = Color(m_Color.r, m_Color.g, m_Color.b, (uint8)(Math.Lerp(255, 0, m_Time)));
	}

	public override void Render()
	{
		// Raylib.DrawRectangleRec(.(Position.x, Position.y, 8, 8), Color);
		Raylib.DrawText(m_Text, (int32)m_Position.x, (int32)m_Position.y, 10, m_DrawColor);
	}
}

class ExplosionParticle : Particle
{
	private readonly Vector2 m_Position;

	private float m_Time = 0.0f;

	public this(Vector2 position)
	{
		m_Position = position;
	}

	public override void Update()
	{
		m_Time += Raylib.GetFrameTime();

		if (m_Time >= 1.0f)
			DestroySelf();
	}

	public override void Render()
	{
		/*
		let radius = Math.Lerp(4, 280, EasingFunctions.OutCubic(Math.Normalize(m_Time, 0, 1.0f, true)));
		let alpha = (uint8)Math.Lerp(125, 0, EasingFunctions.Linear(Math.Normalize(m_Time, 0, 0.4f, true)));
		Raylib.DrawCircleV(m_Position, radius, .(255, 0, 0, alpha));
		*/
	}
}

class WinParticle : Particle
{
	private readonly Vector2 m_Position;

	private float m_Time = 0.0f;

	public this(Vector2 position)
	{
		m_Position = position;
	}

	public override void Update()
	{
		m_Time += Raylib.GetFrameTime();

		if (m_Time >= 1.0f)
			DestroySelf();
	}

	public override void Render()
	{
		let radius = Math.Lerp(6, 280, EasingFunctions.OutCubic(Math.Normalize(m_Time, 0, 1.0f, true)));
		let alpha = (uint8)Math.Lerp(125, 0, EasingFunctions.Linear(Math.Normalize(m_Time, 0, 0.6f, true)));
		Raylib.DrawCircleV(m_Position, radius, .(255, 255, 255, alpha));
	}
}