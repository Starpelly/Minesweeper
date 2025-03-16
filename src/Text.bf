using System;
using RaylibBeef;
namespace Minesweeper;

class Text
{
	public enum DrawTextSize
	{
		Big,
		Small,
		Title,
		Heading,
	}

	public enum DrawTextType
	{
		Outline,
		NoOutline,
		Shadow
	}

	public static float GetTextSize(DrawTextSize size)
	{
		switch (size)
		{
		case .Big: return 24;
		case .Small: return 12;
		case .Title: return 24 * 2;
		case .Heading: return 24;
		}
	}

	public static void DrawText(String text, Vector2 pos, DrawTextSize size, DrawTextType type, uint8 alpha = 255)
	{
		DrawTextColored(text, pos, size, type, .(255, 255, 255, alpha));
	}

	public static void DrawTextColored(String text, Vector2 pos, DrawTextSize size, DrawTextType type, Color color)
	{
		let txtSize = GetTextSize(size);

		if (type == .Outline)
			Raylib.DrawTextEx(Assets.Fonts.NokiaOutline.Font, text, pos, txtSize, 0, .(Color.DarkOutline.r, Color.DarkOutline.g, Color.DarkOutline.b, color.a));
		else if (type == .Shadow)
			Raylib.DrawTextEx(Assets.Fonts.Nokia.Font, text, pos - .(2, -2), txtSize, 0, .(Color.Shadow.r, Color.Shadow.g, Color.Shadow.b, color.a));
		Raylib.DrawTextEx(Assets.Fonts.Nokia.Font, text, pos, txtSize, 0, color);
	}

	public static Vector2 MeasureText(String text, DrawTextSize size)
	{
		return Raylib.MeasureTextEx(Assets.Fonts.Nokia.Font, text, GetTextSize(size), 0);
	}
}