using System;
using Minesweeper;

namespace MinesweeperGUI;

class Program
{
	public static void Main(String[] args)
	{
		let entry = scope EntryPoint();
		entry.Start(args);
	}
}