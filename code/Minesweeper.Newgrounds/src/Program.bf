using System;

using Minesweeper.Game;

namespace Minesweeper.Newgrounds;

class NewgroundsEntry : EntryPoint
{
	public override void OnInit()
	{
#if BF_PLATFORM_WASM
		Newgrounds.Init();
		Newgrounds.Login();
#endif
	}

	public override void RequestPostScore(int points, int combo)
	{
#if BF_PLATFORM_WASM
		Newgrounds.PostScore(points, combo);
#endif
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