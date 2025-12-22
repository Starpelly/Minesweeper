using System;

using Minesweeper;
using Minesweeper.Game;

namespace Minesweeper.Desktop;

class DesktopEntry : EntryPoint
{
	public override void OnInit()
	{
	}

	public override void RequestPostScore(int points, int combo)
	{
	}
}

class Program
{
	public static void Main(String[] args)
	{
		let entry = scope DesktopEntry();
		entry.Start(args);
	}
}