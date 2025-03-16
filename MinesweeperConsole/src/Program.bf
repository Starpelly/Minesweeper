using System;
using Minesweeper;

namespace MinesweeperConsole;

class Program
{
	public static void Main(String[] args)
	{
		let entry = scope EntryPoint();
		entry.Start(args);
	}
}