namespace System;

extension Math
{
	[Inline]
	public static float Repeat(float t, float length)
	{
		return Math.Clamp(t - Math.Floor(t / length) * length, 0.0f, length);
	}

	[Inline]
	public static float Round2Nearest(float val, float interval)
	{
		return val - (val % interval);
	}

	public static float RandomFloat32(float min, float max)
	{
		return (float)Minesweeper.Game.Random.NextDouble() * (max - min) + min;
	}
}