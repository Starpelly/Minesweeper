using System;
using System.Collections;
using System.Diagnostics;
using RaylibBeef;

namespace Minesweeper;

class Game
{
	// -------------------
	// Constants / Structs
	// -------------------

	private const uint32 TILE_SIZE = 16;
	private const uint32 TILE_SPACING = 1;
	private const uint32 LINE_WIDTH = 1;
	private const int BG_CHECKER_SIZE = 16;

	private const uint MAX_LIVES = 3;
	private const float SECONDS_PER_COMBO = 4.0f;
	private const float SECONDS_PER_COMBO_DECREMENTING = 2.0f;
	private const uint CLEARS_PER_COMBO = 8;

	private const float TIME_BETWEEN_BOARDS_WIN = 0.5f;
	private const float TIME_BETWEEN_BOARDS_FAIL = 2.45f;
	private const float TIME_BETWEEN_BOARDS_GAMEOVER = 0.75f;

	private const Color[10] NUMBER_COLORS = .(
		.(0, 0, 0, 255),
		.(57, 90, 211, 255),
		.(0, 135, 81, 255),
		.(219, 0, 69, 255),
		.(126, 37, 83, 255),
		.(131, 118, 156, 255),
		.(0, 135, 81, 255),
		.(211, 99, 140, 255),
		.(69, 69, 69, 255),
		.(25, 25, 25, 255)
	);

	private struct Board
	{
		public int Width = 8;
		public int Height = 8;

		public uint Mines = 10;
	}

	private enum TileState
	{
		Closed,
		Opened,
		Flaged,
		NoMine,
	}

	private enum GameState
	{
		Game,
		Lose,
		Win,
		GameOver
	}

	private class State
	{
		public bool IsPlaying = false;

		public Stopwatch SessionTimer = new .() ~ delete _;
		public Stopwatch StageTimer = new .() ~ delete _;

		public float Points = 0;
		public Stopwatch ComboTimer = new .() ~ delete _;
		public int ComboMult = 1;
		public uint ComboIncrementor = 0; // Every 8 clears, our multipler increases
		public bool DecrementingCombo = false;
		public float MaxComboTimerTime = 0.0f;

		public uint StartMineAdd = 0;

		public uint MineCount = 0;
		public uint FlagCount = 0;

		public uint Lives = 3;

		public uint Stage = 0;

		public Stopwatch NextBoardTimer = new .() ~ delete _;

		public bool WaitingForFirstClick = false;

		public GameState State = .Game;

		public bool[,] Mines ~ delete _;
		public bool[,] Cleared ~ delete _; // "points collected"
		public uint8[,] Numbers ~ delete _;
		public TileState[,] Tiles ~ delete _;
	}

	private Vector2 BOARD_SIZE => .(m_Board.Width * (TILE_SIZE + TILE_SPACING), m_Board.Height * (TILE_SIZE + TILE_SPACING));
	private Vector2 BOARD_POS => .Zero;

	private Vector2I BOARD_MOUSE_COORDS
	{
		get
		{
			let mp = Raylib.GetScreenToWorld2D(GetMousePosition(), m_Camera) - BOARD_POS;
			var ret = mp / (TILE_SIZE + TILE_SPACING);

			if (mp.x < 0)
				ret.x -= 1;
			if (mp.y < 0)
				ret.y -= 1;

			return ret;
		}
	}

	private class ShakeInstance
	{
		public float Strength;
		public float Speed;
		public float Decay;
		public float Time;

		public this(float strength, float speed, float decay)
		{
			this.Strength = strength;
			this.Speed = speed;
			this.Decay = decay;
			this.Time = 0.0f;
		}

		public bool IsFinished => Strength <= 0.01f;
	}

	private List<ShakeInstance> m_CamShakesList = new .() ~ DeleteContainerAndItems!(_);

	// ----------------
	// Static variables
	// ----------------

	public static Random Random = new .() ~ delete _;

	// -----------------
	// Private variables
	// -----------------

	private Board m_Board;
	private State m_State = new .() ~ delete _;

	private Camera2D m_Camera;

	private float m_NewCameraZoom;
	private Vector2 m_NewCameraTarget;

	private Vector2 GetMousePosition()
	{
		return EntryPoint.MousePositionViewport;
	}

	private List<Particle> m_ActiveParticles = new .() ~ DeleteContainerAndItems!(_);
	private List<Particle> m_ParticlesToDelete = new .() ~ delete _;

	private float m_ProgressBarTimer = 0.0f;

	private float m_SessionHighscore = 0.0f;

	// --------------
	// Public methods
	// --------------

	public this()
	{
		m_Board = .();
		m_Camera = Camera2D(.Zero, .Zero, 0, 2);

		m_NewCameraZoom = m_Camera.zoom;
		m_NewCameraTarget = m_Camera.target;

		RestartGame();
	}

	public void ShakeCamera(float strength, float speed, float decay)
	{
		m_CamShakesList.Add(new .(strength, speed, decay));
	}

	public void CreateParticle(Particle particle)
	{
		m_ActiveParticles.Add(particle);
		particle.[Friend]SetGame(this);
	}

	public void RemoveParticle(Particle particle)
	{
		m_ParticlesToDelete.Add(particle);
	}

	public void MakeStage(uint stage)
	{
		uint startMineCount = 6 + m_State.StartMineAdd;

		let newBoard = Board()
		{
			Width = 8,
			Height = 8,
			Mines = Math.Clamp(m_State.Stage + startMineCount, startMineCount, 13)
		};

		Remake(newBoard);
	}

	public void Remake(Board board)
	{
		m_Board = board;

		m_State.State = .Game;

		m_State.MineCount = 0;
		m_State.FlagCount = 0;

		m_State.MaxComboTimerTime = SECONDS_PER_COMBO;

		delete m_State.Mines;
		delete m_State.Cleared;
		delete m_State.Numbers;
		delete m_State.Tiles;

		m_State.Mines = new bool[board.Width, board.Height];
		m_State.Cleared = new bool[board.Width, board.Height];
		m_State.Numbers = new uint8[board.Width, board.Height];
		m_State.Tiles = new TileState[board.Width, board.Height];

		m_State.WaitingForFirstClick = true;

		// Close all tiles by default
		for (var tile in ref m_State.Tiles)
		{
			tile = .Closed;
		}

		centerCamera();
	}

	public void GenerateMines(int safeX, int safeY)
	{
		bool IsInSafeZone(int x, int y)
		{
		    return Math.Abs(x - safeX) <= 1 && Math.Abs(y - safeY) <= 1;
		}

		var minesToCreate = m_Board.Mines;
		while (minesToCreate > 0)
		{
			int x = Random.Next((int32)m_Board.Width);
			int y = Random.Next((int32)m_Board.Height);

			if (!m_State.Mines[x, y] && !IsInSafeZone(x, y))
			{
				m_State.Mines[x, y] = true;
				m_State.MineCount++;
				for (int k = x - 1; k < x + 2; ++k)
				{
					for (int l = y - 1; l < y + 2; ++l)
					{
						if (k >= 0 && l >= 0 && k < m_Board.Width && l < m_Board.Height)
						{
							m_State.Numbers[k, l]++;
						}
					}
				}
				minesToCreate--;
			}
		}

		int totalNumbers = 0;

		for (let x < m_Board.Width)
		{
			for (let y < m_Board.Height)
			{
				if (m_State.Numbers[x, y] > 0 && !m_State.Mines[x, y])
				{
					totalNumbers += m_State.Numbers[x, y];
				}
			}
		}

		Console.WriteLine(totalNumbers);
	}

	public void Open(int x, int y)
	{
		if (m_State.State != .Game) return;
		if (x < 0 || y < 0 || x >= m_Board.Width || y >= m_Board.Height)
		{
			return;
		}

		if (m_State.WaitingForFirstClick)
		{
			GenerateMines(x, y);

			m_State.IsPlaying = true;
			m_State.WaitingForFirstClick = false;

			m_State.SessionTimer.Start();
			m_State.ComboTimer.Start();
			m_State.StageTimer.Start();
		}

		if (m_State.Tiles[x, y] == .Closed)
		{
			m_State.Tiles[x, y] = .Opened;

			let tileType = (x + y) % 2;
			CreateParticle(new OpenedTileParticle(.(x * (TILE_SIZE + TILE_SPACING), y * (TILE_SIZE + TILE_SPACING)), tileType));
			ShakeCamera(1.1f, 4, 2);

			Raylib.PlaySound(Assets.Sounds.Click.Sound);
		}

		// Lose if we opened a mine
		if (m_State.Tiles[x, y] == .Opened && m_State.Mines[x, y] == true)
		{
			Raylib.PlaySound(Assets.Sounds.Boom.Sound);
			ShakeCamera(24, 8, 0.4f);
			CreateParticle(new ExplosionFlashParticle());

			m_State.SessionTimer.Stop();
			m_State.ComboTimer.Stop();
			m_State.StageTimer.Stop();

			m_State.NextBoardTimer.Start();

			m_State.Lives--;
			m_State.State = (m_State.Lives <= 0) ? .GameOver : .Lose;

			if (m_State.State == .GameOver)
			{
				m_SessionHighscore = m_State.Points;
			}

			for (let bx < m_Board.Width)
			{
				for (let by < m_Board.Height)
				{
					if (m_State.Mines[bx, by] && m_State.Tiles[bx, by] != .Flaged)
					{
						m_State.Tiles[bx, by] = .Opened;
					}
					else
					{
						if (!m_State.Mines[bx, by] && m_State.Tiles[bx, by] == .Flaged)
						{
							m_State.Tiles[bx, by] = .NoMine;
						}
					}	
				}
			}
			return;
		}

		if (m_State.Numbers[x, y] == 0)
		{
			// Open the rest of empty tiles that connect
			for (int k = x - 1; k < x + 2; ++k)
			{
				for (int l = y - 1; l < y + 2; ++l)
				{
					if (k >= 0 && l >= 0 && k < m_Board.Width && l < m_Board.Height)
					{
						/*
						if (state == 0 && actField[k, l] != 1)
						{
							if (actField[k][l] == 2)
							{
								flags--;
							}
							actField[k][l] == 0;
						}
						*/

						if (m_State.Tiles[k, l] == .Closed)
						{
							Raylib.PlaySound(Assets.Sounds.ClearArea.Sound);
							Open(k, l);
						}
					}
				}
			}
		}

		checkTileForPoints(x, y);

		// Check to see if we still have unopened tiles before winning
		for (let bx < m_Board.Width)
		{
			for (let by < m_Board.Height)
			{
				if (!m_State.Mines[bx, by] && m_State.Tiles[bx, by] != .Opened)
				{
					return;
				}
			}
		}

		// You win!!!!!
		m_State.State = .Win;
		m_State.SessionTimer.Stop();
		m_State.ComboTimer.Stop();
		m_State.StageTimer.Stop();

		Raylib.PlaySound(Assets.Sounds.Win.Sound);

		// Hack for all tiles in the win state
		// if (false)
		{
			for (let bx < m_Board.Width)
			{
				for (let by < m_Board.Height)
				{
					if (!m_State.Cleared[bx, by])
					if (m_State.Numbers[bx, by] > 0 && !m_State.Mines[bx, by])
					ClearTile(bx, by);
				}
			}
		}

		m_State.NextBoardTimer.Start();
	}

	public void Chord(int x, int y)
	{
		if (m_State.State != .Game) return;
		if (x < 0 || y < 0 || x >= m_Board.Width || y >= m_Board.Height)
		{
			return;
		}
		if (m_State.Tiles[x, y] != .Opened || m_State.Numbers[x, y] <= 0)
		{
			return;
		}

		Console.WriteLine("Chord");

		var expectedFlagCount = m_State.Numbers[x, y];

		// Get number of flags and collect empty cells
		var foundFlagCount = 0;
		var foundClosedCells = scope List<(int, int)>();
		for (int k = x - 1; k < x + 2; ++k)
		{
			for (int l = y - 1; l < y + 2; ++l)
			{
				if (k >= 0 && l >= 0 && k < m_Board.Width && l < m_Board.Height)
				{
					if (m_State.Tiles[k, l] == .Flaged)
					{
						foundFlagCount++;
					}
					else if (m_State.Tiles[k, l] == .Closed)
					{
						foundClosedCells.Add((k, l));
					}
				}
			}
		}

		if (expectedFlagCount != foundFlagCount || foundClosedCells.Count == 0)
		{
			Raylib.PlaySound(Assets.Sounds.FailedChord.Sound);
			ShakeCamera(2, 4, 4);

			// Do nothing
			return;
		}

		Raylib.PlaySound(Assets.Sounds.ClearArea.Sound);
		for (let cell in foundClosedCells)
		{
			Open(cell.0, cell.1);
		}
	}

	public void ChordMines(int x, int y)
	{
		if (m_State.State != .Game) return;
		if (x < 0 || y < 0 || x >= m_Board.Width || y >= m_Board.Height)
		{
			return;
		}
		if (m_State.Tiles[x, y] != .Opened || m_State.Numbers[x, y] <= 0)
		{
			return;
		}

		var expectedTileCount = m_State.Numbers[x, y];
		var foundClosedCells = scope List<(int, int)>();

		for (int k = x - 1; k < x + 2; ++k)
		{
			for (int l = y - 1; l < y + 2; ++l)
			{
				if (k >= 0 && l >= 0 && k < m_Board.Width && l < m_Board.Height)
				{
					if (m_State.Tiles[k, l] == .Closed || m_State.Tiles[k, l] == .Flaged)
					{
						foundClosedCells.Add((k, l));
					}
				}
			}
		}

		if (expectedTileCount != foundClosedCells.Count || foundClosedCells.Count == 0)
		{
			Raylib.PlaySound(Assets.Sounds.FailedChord.Sound);
			ShakeCamera(2, 4, 4);

			// Do nothing
			return;
		}

		for (let cell in foundClosedCells)
		{
			Flag(cell.0, cell.1, false);
		}
	}

	public void Flag(int x, int y, bool allowUnflag = true)
	{
		if (m_State.State != .Game || m_State.WaitingForFirstClick) return;
		if (!m_State.IsPlaying || x < 0 || y < 0 || x >= m_Board.Width || y >= m_Board.Height || m_State.Tiles[x, y] == .Opened)
		{
			return;
		}

		let lastFlagState = m_State.Tiles[x, y] == .Flaged;

		if (allowUnflag)
		{
			m_State.Tiles[x, y] = m_State.Tiles[x, y] == .Flaged ? 0 : .Flaged;
		}
		else
		{
			m_State.Tiles[x, y] = .Flaged;

			if (lastFlagState && m_State.Tiles[x, y] == .Flaged) return;
		}

		if (m_State.Tiles[x, y] == .Flaged != lastFlagState)
			Raylib.PlaySound(Assets.Sounds.Flag.Sound);

		if (m_State.Tiles[x, y] == .Flaged)
		{
			m_State.FlagCount++;
		}
		else
		{
			m_State.FlagCount--;
		}

		checkTileForPoints(x, y);
	}

	public void LeftClickBoard(int x, int y)
	{
		if (x < 0 || y < 0 || x >= m_Board.Width || y >= m_Board.Height)
		{
			return;
		}

		if (m_State.Tiles[x, y] == .Closed)
		{
			Open(x, y);
		}
		else
		{
			if (m_State.Numbers[x, y] > 0)
			{
				Chord(x, y);
			}
			else
			{
				Raylib.PlaySound(Assets.Sounds.Tap.Sound);

			}
		}
	}

	public void RightClickBoard(int x, int y)
	{
		if (!m_State.IsPlaying || x < 0 || y < 0 || x >= m_Board.Width || y >= m_Board.Height)
		{
			return;
		}

		if (m_State.Tiles[x, y] == .Closed || m_State.Tiles[x, y] == .Flaged)
		{
			Flag(x, y);
		}
		else
		{
			if (m_State.Numbers[x, y] > 0)
			{
				ChordMines(x, y);
			}
		}
	}

	private void checkTileForPoints(int origX, int origY)
	{
		bool checkSurrounding(int x, int y)
		{
			uint8 number = m_State.Numbers[x, y];
			uint8 counted = 0;

			for (int k = x - 1; k < x + 2; ++k)
			{
				for (int l = y - 1; l < y + 2; ++l)
				{
					if (k >= 0 && l >= 0 && k < m_Board.Width && l < m_Board.Height)
					{
						if (m_State.Tiles[k, l] == .Closed)
							return false;

						if (/*m_State.Mines[k, l] == true &&*/ m_State.Tiles[k, l] == .Flaged)
						{
							counted++;
						}
					}
				}
			}

			return counted == number;
		}

		// Accumulate points for any tiles that have all their mines flagged
		for (int k = origX - 1; k < origX + 2; ++k)
		{
			for (int l = origY - 1; l < origY + 2; ++l)
			{
				if (k >= 0 && l >= 0 && k < m_Board.Width && l < m_Board.Height)
				{
					if (!m_State.Cleared[k, l])
					if (m_State.Numbers[k, l] > 0 && !m_State.Mines[k, l])
					if (checkSurrounding(k, l))
					{
						ClearTile(k, l);
					}
				}
			}
		}
	}

	private void ClearTile(int x, int y)
	{
		m_State.Cleared[x, y] = true;

		let pointsToGive = m_State.Numbers[x, y];
		m_State.Points += pointsToGive * m_State.ComboMult;

		if (m_State.Points > m_SessionHighscore)
			m_SessionHighscore = m_State.Points;

		CreateParticle(new NewPointsParticle(.((x * (TILE_SIZE + TILE_SPACING)) + (4), y * (TILE_SIZE + TILE_SPACING)), NUMBER_COLORS[pointsToGive], scope $"+{pointsToGive}"));

		m_State.ComboIncrementor++;
		if (m_State.ComboIncrementor >= CLEARS_PER_COMBO)
		{
			m_State.ComboMult++;
			m_State.ComboIncrementor = 0;
		}
		if (m_State.DecrementingCombo)
		{
			m_State.MaxComboTimerTime = SECONDS_PER_COMBO;
		}
		m_State.DecrementingCombo = false;
		m_State.MaxComboTimerTime += 0.25f;

		RestartComboTimer();
	}

	private void RestartComboTimer()
	{
		if (m_State.State != .Game) return;

		m_State.DecrementingCombo = false;
		m_State.ComboTimer.Restart();
	}

	public void RestartGame()
	{
		m_State.Points = 0;
		m_State.ComboMult = 1;
		m_State.ComboIncrementor = 0;
		m_State.DecrementingCombo = false;
		m_State.Lives = 3;
		m_State.MaxComboTimerTime = SECONDS_PER_COMBO;
		m_State.StartMineAdd = 0;

		m_State.SessionTimer.Reset();
		m_State.ComboTimer.Reset();
		m_State.NextBoardTimer.Reset();
		m_State.StageTimer.Reset();
		m_State.Stage = 0;

		MakeStage(m_State.Stage);
		centerCamera();
		m_Camera.zoom = 2;
	}

	// ------
	// Events
	// ------

	public void Update()
	{
		if (Raylib.IsKeyPressed(.KEY_R))
		{
			RestartGame();
		}

		for (let particle in ref m_ParticlesToDelete)
		{
			m_ActiveParticles.Remove(particle);
			delete particle;
		}
		m_ParticlesToDelete.Clear();

		for (let particle in ref m_ActiveParticles)
		{
			particle.Update();
		}

		// Camera manipulation
		// updateCameraControl();
		centerCamera();

		var shakesToRemove = scope List<ShakeInstance>();
		for (let shake in ref m_CamShakesList)
		{
			if (shake.IsFinished)
				shakesToRemove.Add(shake);
		}
		for (let rm in ref shakesToRemove)
		{
			delete rm;
			m_CamShakesList.Remove(rm);
		}
		shakesToRemove.Clear();

		for (let shake in ref m_CamShakesList)
		{
			shake.Time += Raylib.GetFrameTime() * shake.Speed;
			float decayFactor = Math.Exp(-shake.Decay * shake.Time);
			float shakeStrength = shake.Strength * decayFactor;

			m_Camera.target += .(Math.RandomFloat32(-shakeStrength, shakeStrength), Math.RandomFloat32(-shakeStrength, shakeStrength));
		}

#if false
		if ((Raylib.IsMouseButtonDown(.MOUSE_BUTTON_LEFT) && Raylib.IsMouseButtonPressed(.MOUSE_BUTTON_RIGHT))
			|| (Raylib.IsMouseButtonDown(.MOUSE_BUTTON_RIGHT) && Raylib.IsMouseButtonPressed(.MOUSE_BUTTON_LEFT)))
		{
			Chord(BOARD_MOUSE_COORDS.x, BOARD_MOUSE_COORDS.y);
		}
		else
		{
			if (Raylib.IsMouseButtonPressed(.MOUSE_BUTTON_LEFT))
			{
				Open(BOARD_MOUSE_COORDS.x, BOARD_MOUSE_COORDS.y);
			}
			else if (Raylib.IsMouseButtonPressed(.MOUSE_BUTTON_RIGHT))
			{
				Flag(BOARD_MOUSE_COORDS.x, BOARD_MOUSE_COORDS.y);
			}
		}

#else
#endif

		// Update min mines
		{
			if (m_State.StageTimer.Elapsed.TotalSeconds >= 60.0f)
			{
				m_State.StartMineAdd++;

				m_State.StageTimer.Restart();
			}
		}

		// Update combo timer
		if (m_State.State == .Game)
		{
			if (Raylib.IsMouseButtonPressed(.MOUSE_BUTTON_LEFT))
			{
				LeftClickBoard(BOARD_MOUSE_COORDS.x, BOARD_MOUSE_COORDS.y);
			}
			else if (Raylib.IsMouseButtonPressed(.MOUSE_BUTTON_RIGHT))
			{
				RightClickBoard(BOARD_MOUSE_COORDS.x, BOARD_MOUSE_COORDS.y);
			}

			mixin decrementComboMult()
			{
				m_State.ComboMult -= 1;
				m_State.ComboIncrementor = 0;

				m_State.ComboMult = Math.Max(0, m_State.ComboMult);
			}

			if (m_State.ComboTimer.Elapsed.TotalSeconds >= m_State.MaxComboTimerTime)
			{
				if (m_State.DecrementingCombo)
				{
					if (m_State.ComboMult - 1 > 0)
					{
						m_State.ComboTimer.Restart();
						decrementComboMult!();
					}
				}
				else
				{
					m_State.ComboTimer.Restart();
					m_State.DecrementingCombo = true;
					m_State.MaxComboTimerTime = SECONDS_PER_COMBO_DECREMENTING;

					decrementComboMult!();
				}
			}
		}
		else if (m_State.State == .Win)
		{
			if (m_State.NextBoardTimer.Elapsed.TotalSeconds >= TIME_BETWEEN_BOARDS_WIN)
			{
				m_State.ComboTimer.Reset();

				// Go to the next stage
				m_State.Stage++;

				Console.WriteLine(m_State.Stage);

				m_State.NextBoardTimer.Reset();

				MakeStage(m_State.Stage);
			}
		}
		else if (m_State.State == .Lose)
		{
			if (m_State.NextBoardTimer.Elapsed.TotalSeconds >= TIME_BETWEEN_BOARDS_FAIL)
			{
				m_State.ComboMult = 0;
				m_State.ComboIncrementor = 0;
				m_State.ComboTimer.Reset();

				m_State.NextBoardTimer.Reset();

				Remake(m_Board);
			}
		}
		else if (m_State.State == .GameOver)
		{
			if (m_State.NextBoardTimer.Elapsed.TotalSeconds >= TIME_BETWEEN_BOARDS_GAMEOVER)
			{
				if (Raylib.IsMouseButtonDown(.MOUSE_BUTTON_LEFT))
				{
					m_State.NextBoardTimer.Reset();
					RestartGame();
				}
			}
		}
	}

	public void Render()
	{
		renderBackground();

		Raylib.BeginMode2D(m_Camera);

		renderBoard();

		for (let particle in m_ActiveParticles)
		{
			if (particle.[Friend]m_PendingDeletion) continue;
			particle.Render();
		}

		Raylib.EndMode2D();

		// Combo Timer
		{
			// let timeFormatted = scope $"{(int)m_State.ComboTimer.Elapsed.TotalHours:D3}:{m_State.ComboTimer.Elapsed.Minutes:D2}:{m_State.ComboTimer.Elapsed.Seconds:D2}'{m_State.ComboTimer.Elapsed.Milliseconds:D3}";
			let timeTxt = scope $"{m_State.Points} points";

			let fontSize = 20;
			let textPadding = 2;

			let timerX = 0;
			let timerY = 10;

			// let timerMeasureTxt = Raylib.MeasureText(timeTxt, fontSize);

			Raylib.DrawRectangleRec(.(timerX, timerY, 192 + 4, fontSize + textPadding), Color.Black);
			Raylib.DrawText(timeTxt, timerX + 4, timerY + 1 + (textPadding / 2), fontSize, Color.White);
		}
		// Total Timer
		{
			let timeFormatted = scope $"{(int)m_State.SessionTimer.Elapsed.TotalHours:D2}:{m_State.SessionTimer.Elapsed.Minutes:D2}:{m_State.SessionTimer.Elapsed.Seconds:D2}'{m_State.SessionTimer.Elapsed.Milliseconds:D3}";
			let timeTxt = scope $"Time: {timeFormatted}";

			let fontSize = 10;
			let textPadding = 2;

			let timerX = 0;
			let timerY = 32;

			Raylib.DrawRectangleRec(.(timerX, timerY, 88 + 8, fontSize + textPadding), .(25, 25, 25, 255));
			Raylib.DrawText(timeTxt, timerX + 4, timerY + (textPadding / 2), fontSize, Color.White);
		}
		// Highscore
		{
			let timeTxt = scope $"Highscore: {m_SessionHighscore}";

			let fontSize = 10;
			let textPadding = 2;

			let timerX = 0;
			let timerY = 32 + 12;

			Raylib.DrawRectangleRec(.(timerX, timerY, 100 + 4, fontSize + textPadding), .(45, 45, 45, 255));
			Raylib.DrawText(timeTxt, timerX + 4, timerY + (textPadding / 2), fontSize, Color.White);
		}

		// Counters
		{
			void drawCounter(String text, Texture2D texture, Rectangle textureRegion, int32 posY)
			{
				// Raylib.DrawRectangleRec(.(0, posY, 120 + 4, 32), .(25, 25, 25, 150));
				Raylib.DrawTexturePro(texture, textureRegion, .(0 - 2, posY + 2, 32, 32), .Zero, 0, .Shadow);
				Raylib.DrawTexturePro(texture, textureRegion, .(0, posY, 32, 32), .Zero, 0, .White);

				let textOffsetX = 32 + 4;
				Raylib.DrawText(text, textOffsetX - 2, posY + 8 + 2, 20, .Shadow);
				Raylib.DrawText(text, textOffsetX, posY + 8, 20, .White);
			}

			drawCounter(m_State.MineCount.ToString(.. scope .()), Assets.Textures.Bomb.Texture, .(0, 0, 16, 16), 48 + 12);
			drawCounter(((int)(m_State.MineCount - m_State.FlagCount)).ToString(.. scope .()), Assets.Textures.Flags.Texture, .(0, 0, 16, 16), 82 + 12);
		}

		// Combos UI
		{
			// Progress bar
			{
				let barX = 0;
				let barY = 10;

				let fontSize = 20;
				let textPadding = 2;

				float width = 200;

				let barXPos = SCREEN_WIDTH - width;
				let barYPos = barY;

				let barWidth = width;
				let barHeight = fontSize + textPadding;

				m_ProgressBarTimer = Math.Lerp(m_ProgressBarTimer, (float)m_State.ComboTimer.Elapsed.TotalSeconds, Raylib.GetFrameTime() * 20.0f);

				let barInnerPadding = 2;
				let barInnerWidth = (int)Math.Lerp(0, width - barInnerPadding, (m_ProgressBarTimer / m_State.MaxComboTimerTime));

				Raylib.DrawRectangleRec(.(barXPos, barYPos, barWidth, barHeight), .Black);

				// Inner
				// let innerRec = Rectangle((barXPos + barInnerPadding) + barInnerWidth, barYPos + barInnerPadding, width - (barInnerPadding * 2) - barInnerWidth, barHeight - (barInnerPadding * 2));
				let innerRec = Rectangle(barXPos + barInnerPadding, barYPos + barInnerPadding, width - (barInnerPadding * 2), barHeight - (barInnerPadding * 2));
				let innerColor = m_State.DecrementingCombo ? Color(125, 125, 125, 255) : Color.White;
				Raylib.DrawRectangleGradientEx(innerRec, innerColor, innerColor, innerColor, innerColor);

				Raylib.DrawRectangleRec(.(barXPos + barInnerPadding, barYPos + barInnerPadding, barInnerWidth, barHeight - (barInnerPadding * 2)), .Black);
			}

			// Combo Mult
			if (m_State.ComboMult > 1)
			{
				let str = scope $"Combo: x{m_State.ComboMult}";

				let multXPos = (int32)SCREEN_WIDTH - Raylib.MeasureText(str, 20) - 4;
				let multYPos = 36;

				Raylib.DrawText(str, multXPos - 2, multYPos + 2, 20, .Shadow);
				Raylib.DrawText(str, multXPos, multYPos, 20, .White);
			}
		}

		// Lives
		{
			for (let i < MAX_LIVES)
			{
				int invI = Math.Abs((int)(i - MAX_LIVES)) - 1;
				bool noHeart = invI > (int)m_State.Lives - 1;
				Raylib.DrawTexturePro(Assets.Textures.Heart.Texture, .(noHeart ? 11 : 0, 0, 11, 10), .(6 + ((21 + -1) * invI), SCREEN_HEIGHT - 28, 11 * 2, 10 * 2), .Zero, 0, .White);
			}
		}

		if (m_State.State == .Win)
		{
			Raylib.DrawRectangleRec(.(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT), .(0, 0, 0, 200));

			let youWinTxt = "You Win!!!";
			let youWinSize = 30;
			let txtMeasure = Raylib.MeasureText(youWinTxt, youWinSize);

			Raylib.DrawText(youWinTxt, (SCREEN_WIDTH / 2) - (txtMeasure / 2), (SCREEN_HEIGHT / 2) - (youWinSize / 2), youWinSize, Color.White);
		}
		else if (m_State.State == .GameOver)
		{
			Raylib.DrawRectangleRec(.(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT), .(255, 0, 0, 120));

			let youWinTxt = "Game Over!!! :(";
			let youWinSize = 30;
			let txtMeasure = Raylib.MeasureText(youWinTxt, youWinSize);

			if (m_State.NextBoardTimer.Elapsed.TotalSeconds >= TIME_BETWEEN_BOARDS_GAMEOVER)
			{
				let str = "(Left Click to restart)";
				let clTxtMeasure = Raylib.MeasureText(str, 10);
				Raylib.DrawText(str, (SCREEN_WIDTH / 2) - (clTxtMeasure / 2), (SCREEN_HEIGHT / 2) + 20, 10, .White);
			}

			Raylib.DrawText(youWinTxt, (SCREEN_WIDTH / 2) - (txtMeasure / 2), (SCREEN_HEIGHT / 2) - (youWinSize / 2), youWinSize, Color.White);
		}

		// Raylib.DrawCircleV(GetMousePosition(), 4, .Red);

	}

	// ---------------
	// Private methods
	// ---------------

	private void centerCamera()
	{
		m_Camera.target = .(BOARD_SIZE.x * 0.5f, BOARD_SIZE.y * 0.5f);
		m_Camera.offset = .(SCREEN_WIDTH * 0.5f, SCREEN_HEIGHT * 0.5f);
	}

	private void updateCameraControl()
	{
		// Camera panning
		{
			if (Raylib.IsMouseButtonDown(.MOUSE_BUTTON_MIDDLE))
			{
				var delta = Raylib.GetMouseDelta() / EntryPoint.ViewportScale;
				delta = Raymath.Vector2Scale(delta, -1.0f / m_Camera.zoom);
				m_Camera.target = Raymath.Vector2Add(m_Camera.target, delta);
			}
		}

		// Camera zooming
		{
			float wheel = Raylib.GetMouseWheelMove();
			if (wheel != 0)
			{
				var mouseWorldPos = Raylib.GetScreenToWorld2D(GetMousePosition(), m_Camera);

				m_Camera.offset = GetMousePosition();

				m_Camera.target = mouseWorldPos;

				var zoomFactor = 1.0f + (0.25f * Math.Abs(wheel));
				if (wheel < 0) zoomFactor = 1.0f / zoomFactor;
				m_Camera.zoom = Math.Clamp(m_Camera.zoom * zoomFactor, 0.125f, 64.0f);
			}
		}
	}

	private void updateSmoothCameraControl()
	{
		// Camera panning
		{
			if (Raylib.IsMouseButtonDown(.MOUSE_BUTTON_MIDDLE))
			{
				var delta = Raylib.GetMouseDelta();
				delta = Raymath.Vector2Scale(delta, -1.0f / m_Camera.zoom);
				// m_Camera.target = 
				m_NewCameraTarget = Raymath.Vector2Add(m_Camera.target, delta);
			}
		}

		// Camera zooming
		{
			float wheel = Raylib.GetMouseWheelMove();
			if (wheel != 0)
			{
				// Variables
				var originalZoom = m_Camera.zoom;
				var originalPos = m_Camera.target;

				// Calc
				{
					m_Camera.zoom = m_NewCameraZoom;
					m_Camera.target = m_NewCameraTarget;

					var mouseWorldPos = Raylib.GetScreenToWorld2D(GetMousePosition(), m_Camera);

					var newZoom = m_Camera.zoom;
					newZoom += (m_Camera.zoom * wheel) * 0.25f;

					m_Camera.zoom = newZoom;

					var newMouseWorldPos = Raylib.GetScreenToWorld2D(GetMousePosition(), m_Camera);
					var targetDifference = mouseWorldPos - newMouseWorldPos;

					m_NewCameraZoom = newZoom;
					m_NewCameraTarget = m_Camera.target + targetDifference;
				}

				// Reset
				{
					m_Camera.zoom = originalZoom;
					m_Camera.target = originalPos;
				}
			}
		}

		// Camera lerp zoom
		{
			var delta = Raylib.GetFrameTime() * 17.0f;
			// m_Camera.target = Raymath.Vector2Lerp(m_Camera.target, m_NewCameraTarget, delta);
			m_Camera.target = .(BOARD_SIZE.x * 0.5f, BOARD_SIZE.y * 0.5f);
			m_Camera.zoom = Math.Lerp(m_Camera.zoom, m_NewCameraZoom, delta);
			m_Camera.offset = .(SCREEN_WIDTH * 0.5f, SCREEN_HEIGHT * 0.5f);
		}
	}

	private void renderBackground()
	{
		let bgWidth = SCREEN_WIDTH;
		let bgHeight = SCREEN_HEIGHT;

		Raylib.ClearBackground(Color(90, 105, 136, 255));

		let checkerOffsetX = (float)Raylib.GetTime() * 5;
		let checkerOffsetY = (float)Raylib.GetTime() * 0;
		let checkerBoardOffset = Vector2(Math.Repeat(checkerOffsetX, BG_CHECKER_SIZE * 2), Math.Repeat(checkerOffsetY, BG_CHECKER_SIZE * 2));

		for (let y < (bgHeight / BG_CHECKER_SIZE) + 3)
		{
			for (let x < (bgWidth / BG_CHECKER_SIZE) + 3)
			{
				if ((x + y) % 2 == 0)
				{
					let xpos = (x * BG_CHECKER_SIZE) - checkerBoardOffset.x;
					let ypos = (y * BG_CHECKER_SIZE) - checkerBoardOffset.y;

					Raylib.DrawRectangleRec(.(xpos, ypos, BG_CHECKER_SIZE, BG_CHECKER_SIZE), Color(0, 0, 0, 10));
				}
			}
		}
	}

	private void renderBoard()
	{
		Rectangle boardRec = .(BOARD_POS.x, BOARD_POS.y, BOARD_SIZE.x, BOARD_SIZE.y);

		// Board shadow
		Raylib.DrawRectangleRec(boardRec - Rectangle(7, -6, 0, 0), .(0, 0, 0, 40));

		// Board bg
		// Raylib.DrawRectangleRec(boardRec, .(192, 204, 216, 255));
		Raylib.DrawRectangleRec(boardRec, .(93, 105, 129, 255));

		// Board tiles
		{
			for (let x < m_Board.Width)
			{
				for (let y < m_Board.Height)
				{
					Raylib.DrawRectangleRec(.(BOARD_POS.x + (x * (TILE_SIZE + TILE_SPACING)), BOARD_POS.y + (y * (TILE_SIZE + TILE_SPACING)), TILE_SIZE, TILE_SIZE), .(192, 204, 216, 255));
				}
			}
		}

		// Board tiles
		renderBoardTiles();

		// Board cursor frame
		if (m_State.State == .Game)
		{
			if (BOARD_MOUSE_COORDS.x >= 0 && BOARD_MOUSE_COORDS.y >= 0
				&& BOARD_MOUSE_COORDS.x < m_Board.Width && BOARD_MOUSE_COORDS.y < m_Board.Height)
			Raylib.DrawTexture(Assets.Textures.Frame.Texture, (int32)(BOARD_MOUSE_COORDS.x * (TILE_SIZE + TILE_SPACING) - 1), (int32)(BOARD_MOUSE_COORDS.y * (TILE_SIZE + TILE_SPACING) - 1), Color.White);
		}

		// Board outline
		Raylib.DrawRectangleLinesEx(boardRec - Rectangle(1, 1, -1, -1), LINE_WIDTH, .(17, 9, 26, 255));
	}

	private void renderBoardTiles()
	{
		// Functions
		Vector2 getTileDrawPosCenter(int x, int y)
		{
			let drawX = ((x * (TILE_SIZE + TILE_SPACING)) - TILE_SIZE * 0.5f) + TILE_SIZE;
			let drawY = ((y * (TILE_SIZE + TILE_SPACING)) - TILE_SIZE * 0.5f) + TILE_SIZE;

			return Vector2(drawX, drawY);
		}

		void drawNumberTile(Vector2 drawPos, int x, int y)
		{
			let number = m_State.Numbers[x, y];
			let numStr = number.ToString(.. scope .());

			Raylib.DrawText(numStr, ((int32)drawPos.x) - 2, ((int32)drawPos.y) - 4, 8, NUMBER_COLORS[number]);
		}

		void drawFlagTile(int x, int y)
		{
			let centerPos = getTileDrawPosCenter(x, y);

			let frameIndex = Math.Floor(Math.Repeat((float)Raylib.GetTime() * 8, 4));

			Raylib.DrawTextureRec(Assets.Textures.Flags.Texture, .(frameIndex * 16, 0, 16, 16), centerPos - Vector2(9, 7), Color.White);
		}

		void drawClosedTile(int x, int y)
		{
			let row = 0;

			if ((x + y) % 2 == 0)
			{
				Raylib.DrawTextureRec(Assets.Textures.Tiles.Texture, .(0, 18 * row, 18, 18), .(x * (17) - 1, y * 17 - 1), Color.White);
			}
			else
			{
				Raylib.DrawTextureRec(Assets.Textures.Tiles.Texture, .(18, 18 * row, 18, 18), .(x * (17) - 1, y * 17 - 1), Color.White);
			}
		}

		void drawCrossedOutTile(int x, int y)
		{
			let TILE_SIZE_PLUS_OFFSET = (TILE_SIZE + TILE_SPACING);
			let margin = 2;

			let topLeft = Vector2((x * TILE_SIZE_PLUS_OFFSET) + margin, (y * TILE_SIZE_PLUS_OFFSET) + margin);
			let topRight = Vector2(((x * TILE_SIZE_PLUS_OFFSET) + TILE_SIZE) - margin, (y * TILE_SIZE_PLUS_OFFSET) + margin);

			let bottomLeft = Vector2((x * TILE_SIZE_PLUS_OFFSET) + margin, ((y * TILE_SIZE_PLUS_OFFSET) + TILE_SIZE) - margin);
			let bottomRight = topLeft + .(TILE_SIZE - (margin * 2), TILE_SIZE - (margin * 2));

			Raylib.DrawLineEx(topLeft, bottomRight, 1, .(255, 100, 0, 255));
			Raylib.DrawLineEx(bottomLeft, topRight, 1, .(255, 100, 0, 255));
		}

		// Loop through all tiles
		for (let x < m_Board.Width)
		{
			for (let y < m_Board.Height)
			{
				let drawPos = getTileDrawPosCenter(x, y);

				if (m_State.Tiles[x, y] == .Closed || !m_State.IsPlaying)
				{
					drawClosedTile(x, y);
				}
				else if (m_State.Tiles[x, y] == .Flaged)
				{
					drawClosedTile(x, y);
					drawFlagTile(x, y);
				}
				else if (m_State.Tiles[x, y] == .NoMine)
				{
					drawCrossedOutTile(x, y);
				}
				else if (m_State.Tiles[x, y] == .Opened)
				{
					if (m_State.Mines[x, y])
					{
						Raylib.DrawRectangleRec(.(x * (TILE_SIZE + TILE_SPACING), y * (TILE_SIZE + TILE_SPACING), TILE_SIZE, TILE_SIZE), .(210, 45, 31, 255));
						Raylib.DrawCircleV(drawPos, (TILE_SIZE * 0.5f) - 4, Color.Black);
					}
					else if (m_State.Numbers[x, y] > 0) // Draw number tile if greater than 0
					{
						drawNumberTile(drawPos, x, y);
					}
				}
			}
		}

		void drawRecAtTile(int x, int y, int offsetX, int offsetY)
		{
			if (x < 0) return;
			if (y < 0) return;
			if (x >= m_Board.Width) return;
			if (y >= m_Board.Height) return;

			if (x + offsetX < 0) return;
			if (y + offsetY < 0) return;
			if (x + offsetX >= m_Board.Width) return;
			if (y + offsetY >= m_Board.Height) return;
			if (m_State.Tiles[x, y] != .Opened) return;
			if (m_State.Numbers[x, y] == 0) return;

			var color = NUMBER_COLORS[m_State.Numbers[x, y]];
			Raylib.DrawRectangleRec(.((x + offsetX) * (TILE_SIZE + TILE_SPACING), (y + offsetY) * (TILE_SIZE + TILE_SPACING), TILE_SIZE, TILE_SIZE), .(color.r, color.g, color.b, 150));
		}

		// Test
		if (m_State.State == .Game)
		{
			drawRecAtTile(BOARD_MOUSE_COORDS.x, BOARD_MOUSE_COORDS.y, -1, -1);
			drawRecAtTile(BOARD_MOUSE_COORDS.x, BOARD_MOUSE_COORDS.y, -1, 0);
			drawRecAtTile(BOARD_MOUSE_COORDS.x, BOARD_MOUSE_COORDS.y, 1, 0);
			drawRecAtTile(BOARD_MOUSE_COORDS.x, BOARD_MOUSE_COORDS.y, 1, -1);
			drawRecAtTile(BOARD_MOUSE_COORDS.x, BOARD_MOUSE_COORDS.y, 0, -1);
			drawRecAtTile(BOARD_MOUSE_COORDS.x, BOARD_MOUSE_COORDS.y, 0, 1);
			drawRecAtTile(BOARD_MOUSE_COORDS.x, BOARD_MOUSE_COORDS.y, -1, 1);
			drawRecAtTile(BOARD_MOUSE_COORDS.x, BOARD_MOUSE_COORDS.y, 1, 1);
		}
	}
}