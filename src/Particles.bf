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
	public Vector2 Position;
	public float Scale = 1.0f;
	public float Rotation = 0.0f;
	public float AngleOffset = 0.0f;

	private uint m_TileType = 0;
	private int m_GraphicIndex = 0;

	private Vector2 m_Velocity = .Zero;
	private float gravity = 3.1f;
	private float m_Opacity = 1.0f;

	public this(Vector2 position, uint type, int graphicIndex)
	{
		Position = position;
		m_TileType = type;
		m_GraphicIndex = graphicIndex;

		gravity = Math.RandomFloat32(10.5f, 16.3f) * 64;
		m_Velocity.x = (Game.Random.Next(0, 2) == 0 ? -1 : 1) * Math.RandomFloat32(48, 85);
		m_Velocity.y = -290;
	}

	public override void Update()
	{
		m_Velocity += .(0, gravity) * Raylib.GetFrameTime();

		Position += m_Velocity * Raylib.GetFrameTime();

		// Rotation = Math.Atan2(m_Velocity.y, m_Velocity.x) * (180.0f / Math.PI_f);
		AngleOffset += (m_Velocity.x * 10) * Raylib.GetFrameTime();

		Scale -= 1.3f * Raylib.GetFrameTime();

		m_Opacity -= 1.3f * Raylib.GetFrameTime();

		if (Scale < 0.0f || m_Opacity <= 0.0f)
			DestroySelf();
	}

	public override void Render()
	{
		let row = m_TileType;

		let color = Color(255, 255, 255, (uint8)(m_Opacity * 255.0f));
		// Raylib.DrawRectanglePro(.(Position.x, Position.y + 12, 18, 18), .(9, 9), Rotation, .(0, 0, 0, 50));
		if (m_GraphicIndex == 0)
		{
			Raylib.DrawTexturePro(Assets.Textures.Tiles.Texture, .(0, 18 * row, 18, 18), .(Position.x + 8, Position.y + 8, 18 * Scale, 18 * Scale), Vector2(9, 9) * Scale, Rotation + AngleOffset, color);
		}
		else
		{
			Raylib.DrawTexturePro(Assets.Textures.Tiles.Texture, .(18, 18 * row, 18, 18), .(Position.x + 8, Position.y + 8, 18 * Scale, 18 * Scale), Vector2(9, 9) * Scale, Rotation + AngleOffset, color);
		}
	}
}

class ExplosionFlashParticle : Particle
{
	private float m_Time;

	public this()
	{
		m_Time = 0.7f;
	}

	public override void Update()
	{
		m_Time -= Raylib.GetFrameTime();
		if (m_Time <= 0.0f)
			DestroySelf();
	}

	public override void Render()
	{
		Raylib.DrawRectangle(-10000, -10000, 100000, 100000, .(255, 0, 0, (uint8)(m_Time * 255.0f)));
	}
}

class NewPointsParticle : Particle
{
	private Vector2 Position;
	private Color Color;

	private String Text = new .() ~ delete _;

	private float m_Time = 0.0f;
	private Color m_DrawColor;

	public this(Vector2 position, Color color, String text)
	{
		Position = position;
		Color = color;
		Text.Append(text);
	}

	public override void Update()
	{
		m_Time += Raylib.GetFrameTime();
		Position.y -= 30 * Raylib.GetFrameTime();

		if (m_Time >= 1.0f)
			DestroySelf();

		m_DrawColor = Color(Color.r, Color.g, Color.b, (uint8)(Math.Lerp(255, 0, m_Time)));
	}

	public override void Render()
	{
		// Raylib.DrawRectangleRec(.(Position.x, Position.y, 8, 8), Color);
		Raylib.DrawText(Text, (int32)Position.x, (int32)Position.y, 10, m_DrawColor);
	}
}