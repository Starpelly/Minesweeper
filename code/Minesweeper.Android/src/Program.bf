using System;

using Minesweeper.Game;

namespace Minesweeper.Android;

class AndroidEntry : EntryPoint
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
	[Export, LinkName("Minesweeper_Android_Main")]
	public static void Android_Main()
	{
		let entry = scope AndroidEntry();
		entry.Start(null);
	}
}