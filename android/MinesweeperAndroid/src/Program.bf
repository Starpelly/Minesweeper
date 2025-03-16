using System;

using Minesweeper;

namespace BeefAndroid;

class Program
{
	[Export, LinkName("Minesweeper_Android_Main")]
	public static void Android_Main()
	{
		let entry = scope Minesweeper.EntryPoint();
		entry.Start(null);
	}
}