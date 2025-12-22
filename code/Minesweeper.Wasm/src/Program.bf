using System;

using Minesweeper.Game;

namespace Minesweeper.Wasm;

// The difference between this and Desktop? Nothing. But it felt right to separate these?
class NewgroundsEntry : EntryPoint
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
		let entry = scope NewgroundsEntry();
		entry.Start(args);
	}
}