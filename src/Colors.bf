namespace RaylibBeef;

public struct Vector2I
{
	public int x = 0;
	public int y = 0;

	public this(int x, int y)
	{
		this.x = x;
		this.y = y;
	}

	public static implicit operator Vector2I(Vector2 vec)
	{
		return .((int)vec.x, (int)vec.y);
	}
}

extension Vector2
{
	public static Vector2 Zero => .(0, 0);
	public static Vector2 One => .(1, 1);

	// ------------------
	// Operator Overloads
	// ------------------

	public static Self operator +(Self a, Self b) => .(a.x + b.x, a.y + b.y);
	public static Self operator -(Self a, Self b) => .(a.x - b.x, a.y - b.y);
	public static Self operator *(Self a, Self b) => .(a.x * b.x, a.y * b.y);
	public static Self operator /(Self a, Self b) => .(a.x / b.x, a.y / b.y);
	public static Self operator -(Self a) => .(-a.x, -a.y);
	public static Self operator +(Self a, float d) => .(a.x + d, a.y + d);
	public static Self operator +(float a, Self d) => .(a + d.x, a + d.y);
	public static Self operator -(Self a, float d) => .(a.x - d, a.y - d);
	public static Self operator -(float a, Self d) => .(a - d.x, a - d.y);
	public static Self operator *(Self a, float d) => .(a.x * d, a.y * d);
	public static Self operator *(float a, Self d) => .(a * d.x, a * d.y);
	public static Self operator /(Self a, float d) => .(a.x / d, a.y / d);
	public static Self operator /(float a, Self d) => .(a / d.x, a / d.y);
}

extension Rectangle
{
	public static Self operator +(Self a, Self b) => .(a.x + b.x, a.y + b.y, a.width + b.width, a.height + b.height);
	public static Self operator -(Self a, Self b) => .(a.x - b.x, a.y - b.y, a.width - b.width, a.height - b.height);
	public static Self operator *(Self a, Self b) => .(a.x * b.x, a.y * b.y, a.width * b.width, a.height * b.height);
	public static Self operator /(Self a, Self b) => .(a.x / b.x, a.y / b.y, a.width / b.width, a.height / b.height);
}

extension Color
{
	public static Color White => .(255, 255, 255, 255);
	public static Color Black => .(0, 0, 0, 255);
	public static Color Transparent => .(255, 255, 255, 0);

	public static Color Red => .(255, 0, 0, 255);
	public static Color Green => .(0, 255, 0, 255);
	public static Color Blue => .(0, 0, 255, 255);

	public static Color Shadow => .(0, 0, 0, 100);

	public static Color ScreenFade => .(25, 25, 25, 255);

	public static Color DarkOutline => .Black;
}
