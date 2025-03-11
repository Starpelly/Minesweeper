using System;
using System.Collections;
using System.Diagnostics;
using RaylibBeef;

namespace Minesweeper;

class Game
{
	// ---------
	// Constants
	// ---------

	private static int32 UI_SCALE => SCREEN_WIDTH / 640;
	private static int32 UI_SCREEN_WIDTH => BASE_SCREEN_WIDTH / UI_SCALE;
	private static int32 UI_SCREEN_HEIGHT => BASE_SCREEN_HEIGHT / UI_SCALE;

	private static float BASE_CAMERA_ZOOM => (SCREEN_WIDTH / 640) * 2;

	private const uint32 TILE_SIZE = 16;
	private const uint32 TILE_SPACING = 1;
	private const uint32 LINE_WIDTH = 1;
	private const int BG_CHECKER_SIZE = 48;

	private const uint MAX_LIVES = 3;
	private const float SECONDS_PER_COMBO = 4.0f;
	private const float SECONDS_PER_COMBO_DECREMENTING = 2.0f;
	private const uint CLEARS_PER_COMBO = 8;

	private const float TIME_BETWEEN_BOARDS_WIN = 0.5f;
	private const float TIME_BETWEEN_BOARDS_FAIL = 2.45f;
	private const float TIME_BETWEEN_BOARDS_GAMEOVER = 0.75f;

	private const double POINTS_PER_BOARD_COLUMN = 8000; // 8k
	private const double POINTS_PER_BOARD_ROW = 50000; // 50k

	private const uint DEFAULT_BOARD_WIDTH = 8;
	private const uint DEFAULT_BOARD_HEIGHT = 8;
	private const uint DEFAULT_BOARD_MINES = 6;

	private const uint DEFAULT_TILE_TYPE = 0;

	private const float SECONDS_PER_MINE_MAX = 60.0f;
	private const float SECONDS_PER_MINE_MIN = 15.0f;

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

	// -----
	// Enums
	// -----

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

	// -----------------
	// Structs / Classes
	// -----------------
	
	private struct Board
	{
		public int Width = 8;
		public int Height = 8;

		public uint Mines = 10;
	}

	private class ComboTimer
	{
		public float ElapsedSeconds = 0.0f;

		private bool m_IsRunning = false;

		public void Start()
		{
			m_IsRunning = true;
		}

		public void Stop()
		{
			m_IsRunning = false;
		}

		public void Restart()
		{
			m_IsRunning = true;
			ElapsedSeconds = 0.0f;
		}

		public void Reset()
		{
			m_IsRunning = false;
			ElapsedSeconds = 0.0f;
		}

		public void Update()
		{
			if (m_IsRunning)
			{
				ElapsedSeconds += Raylib.GetFrameTime();
			}
		}
	}

	private class State
	{
		public bool IsPlaying = false;

		public Stopwatch SessionTimer = new .() ~ delete _;
		public Stopwatch MineTimer = new .() ~ delete _;
		public Stopwatch NextBoardTimer = new .() ~ delete _;

		public float SecondsToNewMine = 0.0f;

		public float Points = 0;
		public ComboTimer ComboTimer = new .() ~ delete _;
		public int ComboMult = 1;
		public uint ComboIncrementor = 0; // Every 8 clears, our multipler increases
		public bool DecrementingCombo = false;
		public float MaxComboTimerTime = 0.0f;

		public uint StartMineAdd = 0;

		public uint MineCount = 0;
		public uint FlagCount = 0;

		public uint Lives = 3;

		public uint Stage = 0;

		public uint NextColumnCount = 0;
		public uint NextRowCount = 0;

		public float NextPointsForWidthAdd = 0.0f;
		public float NextPointsForHeightAdd = 0.0f;

		public uint TileType = 0;

		public bool WaitingForFirstClick = false;

		public GameState State = .Game;

		public bool[,] Mines ~ delete _;
		public bool[,] Cleared ~ delete _; // "points collected"
		public uint8[,] Numbers ~ delete _;
		public TileState[,] Tiles ~ delete _;
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

	private class Highscore
	{
		public float Points = 0.0f;
		public Stopwatch BestTimeTimer = new .() ~ delete _;
		public int Combo = 0;
	}

	// ----------------
	// Static variables
	// ----------------

	public static Random Random = new .() ~ delete _;

	// -----------------
	// Private variables
	// -----------------

	private List<ShakeInstance> m_CamShakesList = new .() ~ DeleteContainerAndItems!(_);
	private Vector2 m_CamShakeInfluence = .Zero;

	private Board m_Board;
	private State m_State = new .() ~ delete _;

	private Camera2D m_Camera;
	private float m_TargetCameraZoom = 0.0f;

	private float m_NewCameraZoom;
	private Vector2 m_NewCameraTarget;

	private List<Particle> m_ActiveParticles = new .() ~ DeleteContainerAndItems!(_);
	private List<Particle> m_ParticlesToDelete = new .() ~ delete _;

	private float m_ProgressBarTimer = 0.0f;

	private Highscore m_SessionHighscore = new .() ~ delete _;

	private RenderTexture2D m_UIRenderTexture;

	// -----------------
	// Private accessors
	// -----------------

	private Vector2 GetBoardSize() => .(m_Board.Width * (TILE_SIZE + TILE_SPACING), m_Board.Height * (TILE_SIZE + TILE_SPACING));
	private Vector2 GetBoardPos() => .Zero;

	private Vector2I GetBoardMouseCoords()
	{
		let mp = Raylib.GetScreenToWorld2D(GetMousePosition(), m_Camera) - GetBoardPos();
		var ret = mp / (TILE_SIZE + TILE_SPACING);

		if (mp.x < 0)
			ret.x -= 1;
		if (mp.y < 0)
			ret.y -= 1;

		return ret;
	}

	private Vector2 GetMousePosition()
	{
#if GAME_SCREEN_FREE
		return Raylib.GetMousePosition();
#else
		return EntryPoint.MousePositionViewport;
#endif
	}

	// --------------
	// Public methods
	// --------------

	public this()
	{
		m_Board = .();
		m_Camera = Camera2D(.Zero, .Zero, 0, BASE_CAMERA_ZOOM);

		m_TargetCameraZoom = m_Camera.zoom;
		m_NewCameraZoom = m_Camera.zoom;
		m_NewCameraTarget = m_Camera.target;

		m_UIRenderTexture = Raylib.LoadRenderTexture(UI_SCREEN_WIDTH, UI_SCREEN_HEIGHT);

		RestartGame();
	}

	public ~this()
	{
		Raylib.UnloadRenderTexture(m_UIRenderTexture);
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
		uint startMineCount = DEFAULT_BOARD_MINES + m_State.StartMineAdd;

		let newBoard = Board()
		{
			Width = (int)Math.Clamp(m_State.NextColumnCount, DEFAULT_BOARD_WIDTH, 30),
			Height = (int)Math.Clamp(m_State.NextRowCount, DEFAULT_BOARD_HEIGHT, 16),
			Mines = Math.Clamp(startMineCount, startMineCount, 99)
		};
		Remake(newBoard, false);
	}

	public void Remake(Board board, bool loseState)
	{
		m_Board = board;

		if (loseState)
		{
			// Add two mines every fail as a punishment
			m_Board.Mines += 2;
		}

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

	public void Open(int x, int y, bool wasWaitingForFirstClick = false)
	{
		if (m_State.State != .Game) return;
		if (x < 0 || y < 0 || x >= m_Board.Width || y >= m_Board.Height)
		{
			return;
		}

		bool wasWaitingFC = m_State.WaitingForFirstClick;
		if (wasWaitingForFirstClick)
			wasWaitingFC = true;
		if (m_State.WaitingForFirstClick)
		{
			GenerateMines(x, y);

			m_State.IsPlaying = true;
			m_State.WaitingForFirstClick = false;

			m_State.SessionTimer.Start();
			m_State.ComboTimer.Start();
			m_State.MineTimer.Start();
		}

		if (m_State.Tiles[x, y] == .Closed)
		{
			m_State.Tiles[x, y] = .Opened;

			let tileType = (x + y) % 2;
			CreateParticle(new OpenedTileParticle(.(x * (TILE_SIZE + TILE_SPACING), y * (TILE_SIZE + TILE_SPACING)), m_State.TileType, tileType));
			ShakeCamera(1f, 4, 2);

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
			m_State.MineTimer.Stop();

			m_State.NextBoardTimer.Start();

			m_State.Lives--;
			m_State.State = (m_State.Lives <= 0) ? .GameOver : .Lose;

			if (m_State.State == .GameOver)
			{
				// Raylib.PlaySound(Assets.Sounds.GameOver.Sound);
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
						if (m_State.Tiles[k, l] == .Closed)
						{
							Raylib.PlaySound(Assets.Sounds.ClearArea.Sound);
							Open(k, l, wasWaitingFC);
						}
					}
				}
			}
		}

		if (!wasWaitingForFirstClick)
		{
			m_State.ComboTimer.ElapsedSeconds -= 0.25f;
			m_State.ComboTimer.ElapsedSeconds = Math.Max(m_State.ComboTimer.ElapsedSeconds, 0.0f);
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
		m_State.MineTimer.Stop();

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
					SolveTile(bx, by);
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
						SolveTile(k, l);
					}
				}
			}
		}
	}

	private void SolveTile(int x, int y)
	{
		m_State.Cleared[x, y] = true;

		let pointsToGive = m_State.Numbers[x, y];

		AddPoints(pointsToGive * m_State.ComboMult);
		// m_State.MaxComboTimerTime += 0.25f;

		CreateParticle(new NewPointsParticle(.((x * (TILE_SIZE + TILE_SPACING)) + (4), y * (TILE_SIZE + TILE_SPACING)), NUMBER_COLORS[pointsToGive], scope $"+{pointsToGive}"));

		RestartComboTimer();
	}

	private void AddPoints(float points)
	{
		m_State.Points += points;

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

		if (m_State.Points > m_SessionHighscore.Points)
		{
			m_SessionHighscore.Points = m_State.Points;
		}
		if (m_State.ComboMult > m_SessionHighscore.Combo)
		{
			m_SessionHighscore.Combo = m_State.ComboMult;
		}

		if (m_State.Points >= m_State.NextPointsForWidthAdd)
		{
			m_State.NextColumnCount++;
			m_State.NextPointsForWidthAdd += (float)POINTS_PER_BOARD_COLUMN;

			m_State.SecondsToNewMine *= 0.75f;
			m_State.SecondsToNewMine = Math.Clamp(m_State.SecondsToNewMine, SECONDS_PER_MINE_MIN, SECONDS_PER_MINE_MAX);
		}
		if (m_State.Points >= m_State.NextPointsForHeightAdd)
		{
			m_State.NextRowCount++;
			m_State.NextPointsForHeightAdd += (float)POINTS_PER_BOARD_ROW;

			m_State.SecondsToNewMine *= 0.75f;
			m_State.SecondsToNewMine = Math.Clamp(m_State.SecondsToNewMine, SECONDS_PER_MINE_MIN, SECONDS_PER_MINE_MAX);
		}
	}

	private void RestartComboTimer()
	{
		if (m_State.State != .Game) return;

		m_State.DecrementingCombo = false;
		m_State.ComboTimer.Restart();
	}

	public void RestartGame()
	{
		m_State.SecondsToNewMine = SECONDS_PER_MINE_MAX;

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
		m_State.MineTimer.Reset();
		m_SessionHighscore.BestTimeTimer.Stop();
		m_State.Stage = 0;

		m_State.NextColumnCount = DEFAULT_BOARD_WIDTH;
		m_State.NextRowCount = DEFAULT_BOARD_HEIGHT;
		m_State.NextPointsForWidthAdd = (float)POINTS_PER_BOARD_COLUMN;
		m_State.NextPointsForHeightAdd = (float)POINTS_PER_BOARD_ROW;

		m_State.TileType = DEFAULT_TILE_TYPE;

		MakeStage(m_State.Stage);
		centerCamera();
	}

	// ------
	// Events
	// ------

	public void Update()
	{
#if DEBUG
		// Debug: Restart game
		if (Raylib.IsKeyPressed(.KEY_R))
		{
			RestartGame();
		}

		// Debug: Add 1k points
		if (Raylib.IsKeyPressed(.KEY_P))
		{
			AddPoints(1000);
		}

		// Debug: Clear current board
		if (Raylib.IsKeyPressed(.KEY_C))
		{
			for (let x < m_Board.Width)
			{
				for (let y < m_Board.Height)
				{
					if (!m_State.Mines[x, y])
					{
						Open(x, y);
					}
				}
			}
		}

		// Debug: Increase board height
		if (Raylib.IsKeyPressed(.KEY_UP))
		{
			let b = Board()
			{
				Width = m_Board.Width,
				Height = m_Board.Height + 1,
				Mines = m_Board.Mines
			};
			Remake(b, false);
		}
		// Debug: Decrease board height
		if (Raylib.IsKeyPressed(.KEY_DOWN))
		{
			let b = Board()
			{
				Width = m_Board.Width,
				Height = m_Board.Height - 1,
				Mines = m_Board.Mines
			};
			Remake(b, false);
		}

		// Debug: Increase board width
		if (Raylib.IsKeyPressed(.KEY_LEFT))
		{
			let b = Board()
			{
				Width = m_Board.Width - 1,
				Height = m_Board.Height,
				Mines = m_Board.Mines
			};
			Remake(b, false);
		}
		// Decrease board height
		if (Raylib.IsKeyPressed(.KEY_RIGHT))
		{
			let b = Board()
			{
				Width = m_Board.Width + 1,
				Height = m_Board.Height,
				Mines = m_Board.Mines
			};
			Remake(b, false);
		}
#endif

#if GAME_SCREEN_FREE
		let baseZoom = 6.0f;
		let baseBoardSize = BOARD_SIZE * baseZoom;

		// Camera zoom
		if (SCREEN_WIDTH < (baseBoardSize.x))
		{
			// m_Camera.zoom = baseZoom - ((baseBoardSize.x - SCREEN_WIDTH) / baseZoom);
			let norm = Math.Normalize(SCREEN_WIDTH, 0, baseBoardSize.x);
			let lerp = Math.Lerp(0, baseZoom, norm);
			m_Camera.zoom = lerp;
		}
		else
		{
			m_Camera.zoom = baseZoom;
		}
		Console.WriteLine(EntryPoint.ViewportScale);
		/*
		if (m_Board.Height > 8 || m_State.NextColumnCount > 16)
		{
			m_Camera.zoom = 1f;
		}
		*/
#elif false
		let baseZoom = 4.0f;

		/*
		if (baseBoardSize.x >= 1088.0f)
		{
			{
				let norm = Math.Normalize(SCREEN_WIDTH - 192, 0, baseBoardSize.x);
				let lerp = Math.Lerp(0, 1, norm);
				lerpVec.x = lerp;
			}


			if (baseBoardSize.y >= 884.0f)
			{
				let norm = Math.Normalize(SCREEN_HEIGHT - 182, 0, baseBoardSize.y);
				let lerp = Math.Lerp(0, 1, norm);
				lerpVec.x = lerp;
			}
			else
			{

			}

			Console.WriteLine(baseBoardSize.y);
		}
		*/

		var newZoomMult = 1.0f;
		while (true)
		{
			let refBoardSize = BOARD_SIZE * newZoomMult;

			/*
			if (refBoardSize.x >= (272.0f / newZoomMult))
			{
				let norm = Math.Normalize(refBoardSize.x, 0, SCREEN_WIDTH - 192, true);
				let lerp = Math.Lerp(1, 0, norm);
				newZoomMult = lerp;

				if (newZoomMult == 1.0f)
					break;

				continue;
			}
			*/

			if (refBoardSize.y > (136.0f / newZoomMult))
			{
				Console.WriteLine(refBoardSize.y);
				let norm = Math.Normalize(refBoardSize.y, 0, SCREEN_HEIGHT - 182, true);
				let lerp = Math.Lerp(1, 0, norm);
				newZoomMult = lerp;

				if (newZoomMult == 1.0f)
					break;

				continue;
			}

			break;
		}
		m_Camera.zoom = newZoomMult * baseZoom;

		/*
		if (baseBoardSize.y >= 544.0f)
		{
			let norm = Math.Normalize(SCREEN_HEIGHT - 182, 0, baseBoardSize.y);
			let lerp = Math.Lerp(0, 1, norm);
			lerpVec.y = lerp;
		}
		*/

		// m_Camera.zoom = (lerpVec.x / lerpVec.y) * baseZoom;

#else
		m_TargetCameraZoom = 1.0f;

		if (m_Board.Width > 16 || m_Board.Height > 8)
		{
			m_TargetCameraZoom = 0.75f;
		}
		if (m_Board.Width > 21 || m_Board.Height > 10)
		{
			m_TargetCameraZoom = 0.625f;
		}
		if (m_Board.Width > 25 || m_Board.Height > 12)
		{
			m_TargetCameraZoom = 0.5f;
		}
		if (m_Board.Width > 31 || m_Board.Height > 15)
		{
			m_TargetCameraZoom = 0.438f;
		}
		if (m_Board.Width > 36 || m_Board.Height > 18)
		{
			m_TargetCameraZoom = 0.25f;
		}

		m_Camera.zoom = Math.Lerp(m_Camera.zoom, m_TargetCameraZoom * BASE_CAMERA_ZOOM, Raylib.GetFrameTime() * 18.0f);
#endif

		// Update timers
		{
			m_State.ComboTimer.Update();
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

		// Update camera shake
		{
			m_CamShakeInfluence = .Zero;

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

				m_CamShakeInfluence += .(Math.RandomFloat32(-shakeStrength, shakeStrength), Math.RandomFloat32(-shakeStrength, shakeStrength));
				// m_Camera.target += .(Math.RandomFloat32(-shakeStrength, shakeStrength), Math.RandomFloat32(-shakeStrength, shakeStrength));
			}
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
			if (m_State.MineTimer.Elapsed.TotalSeconds >= m_State.SecondsToNewMine)
			{
				m_State.StartMineAdd++;
				m_State.MineTimer.Restart();
			}
			Console.WriteLine(scope $"0: {m_State.MineTimer.Elapsed.TotalSeconds}, 1: {m_State.SecondsToNewMine}");
		}

		// Update combo timer
		if (m_State.State == .Game)
		{
			if (Raylib.IsMouseButtonPressed(.MOUSE_BUTTON_LEFT))
			{
				LeftClickBoard(GetBoardMouseCoords().x, GetBoardMouseCoords().y);
			}
			else if (Raylib.IsMouseButtonPressed(.MOUSE_BUTTON_RIGHT))
			{
				RightClickBoard(GetBoardMouseCoords().x, GetBoardMouseCoords().y);
			}

			mixin decrementComboMult()
			{
				m_State.ComboMult -= 1;
				m_State.ComboIncrementor = 0;

				m_State.ComboMult = Math.Max(1, m_State.ComboMult);
			}

			if (m_State.Points >= m_SessionHighscore.Points)
			{
				m_SessionHighscore.BestTimeTimer.CopyFrom(m_State.SessionTimer);
			}

			if (m_State.ComboTimer.ElapsedSeconds >= m_State.MaxComboTimerTime)
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

				// m_State.TileType = (uint)Random.Next(0, 7);

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

				// m_State.TileType = (uint)Random.Next(0, 7);

				Remake(m_Board, true);
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

	public void RenderUI()
	{
		Raylib.BeginTextureMode(m_UIRenderTexture);
		Raylib.ClearBackground(.(0, 0, 0, 0));
		renderUI();
		Raylib.EndTextureMode();
	}

	public void Render()
	{
		// Render game shit
		{
			renderBackground();

			let drawCamera = Camera2D(m_Camera.offset, m_Camera.target + m_CamShakeInfluence, m_Camera.rotation, m_Camera.zoom);
			Raylib.BeginMode2D(drawCamera);
			{
				renderBoard();

				for (let particle in m_ActiveParticles)
				{
					if (particle.[Friend]m_PendingDeletion) continue;
					particle.Render();
				}
			}
			Raylib.EndMode2D();

			m_CamShakeInfluence = .Zero;
		}

		// Draw UI texture
		Raylib.BeginBlendMode(.BLEND_ALPHA_PREMULTIPLY);
		Raylib.DrawTexturePro(
			m_UIRenderTexture.texture,
			.(0, 0, m_UIRenderTexture.texture.width, -m_UIRenderTexture.texture.height),
			.(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT),
			.(0, 0),
			0,
			.White
		);
		Raylib.EndBlendMode();

		if (m_State.State == .Win)
		{
			Raylib.DrawRectangleRec(.(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT), .(0, 0, 0, 200));

			let youWinTxt = "You Win!!!";
			let youWinSize = 30 * UI_SCALE;
			let txtMeasure = Raylib.MeasureText(youWinTxt, youWinSize);

			Raylib.DrawText(youWinTxt, (int32)(SCREEN_WIDTH / 2) - (txtMeasure / 2), (int32)(SCREEN_HEIGHT / 2) - (youWinSize / 2), youWinSize, Color.White);
		}
		else if (m_State.State == .GameOver)
		{
			Raylib.DrawRectangleRec(.(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT), .(255, 0, 0, 120));

			let youWinTxt = "Game Over!!! :(";
			let youWinSize = 30 * UI_SCALE;
			let txtMeasure = Raylib.MeasureText(youWinTxt, youWinSize);

			if (m_State.NextBoardTimer.Elapsed.TotalSeconds >= TIME_BETWEEN_BOARDS_GAMEOVER)
			{
				let str = "(Left Click to restart)";
				let clTxtMeasure = Raylib.MeasureText(str, 10 * UI_SCALE);
				Raylib.DrawText(str, (int32)(SCREEN_WIDTH / 2) - (clTxtMeasure / 2), (int32)(SCREEN_HEIGHT / 2) + 20, 10 * UI_SCALE, .White);
			}

			Raylib.DrawText(youWinTxt, (int32)(SCREEN_WIDTH / 2) - (txtMeasure / 2), (int32)(SCREEN_HEIGHT / 2) - (youWinSize / 2), youWinSize, Color.White);
		}
	}

	// ---------------
	// Private methods
	// ---------------

	private void centerCamera()
	{
		m_Camera.target = .(GetBoardSize().x * 0.5f, GetBoardSize().y * 0.5f);
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
			m_Camera.target = .(GetBoardSize().x * 0.5f, GetBoardSize().y * 0.5f);
			m_Camera.zoom = Math.Lerp(m_Camera.zoom, m_NewCameraZoom, delta);
			m_Camera.offset = .(SCREEN_WIDTH * 0.5f, SCREEN_HEIGHT * 0.5f);
		}
	}

	private void renderUI()
	{
		void timeFormatted(String outStr, Stopwatch stopwatch)
		{
			outStr.Append(scope $"{(int)stopwatch.Elapsed.TotalHours:D2}:{stopwatch.Elapsed.Minutes:D2}:{stopwatch.Elapsed.Seconds:D2}'{stopwatch.Elapsed.Milliseconds:D3}");
		}

		// Top left
		{
			void drawSideThing(String text, int32 timerWidth, int32 timerY, int32 fontSize, int32 cornerWidth, Color bgColor)
			{
				let textPadding = 2;

				let timerHeight = fontSize + textPadding;

				let timerX = 0;

				Raylib.DrawRectangleRec(.(timerX, timerY, timerWidth - cornerWidth, timerHeight), bgColor);

				let triangleX = (timerX + timerWidth) - cornerWidth;
				Raylib.DrawTriangle(.(triangleX, timerY), .(triangleX, timerY + timerHeight), .(triangleX + cornerWidth, timerY), bgColor);

				Raylib.DrawText(text, timerX + 4, timerY + (textPadding / 2), fontSize, Color.White);
			}

			// Points
			{
				drawSideThing(scope $"{m_State.Points} points", 196, 10, 20, 22, .Black);
			}
			// Total Timer
			{
				drawSideThing(scope $"Time: {timeFormatted(.. scope .(), m_State.SessionTimer)}", 174, 32, 10, 12, .(25, 25, 25, 255));
			}
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

			drawCounter(m_State.MineCount.ToString(.. scope .()), Assets.Textures.Bomb.Texture, .(0, 0, 16, 16), 48);
			drawCounter(((int)(m_State.MineCount - m_State.FlagCount)).ToString(.. scope .()), Assets.Textures.Flags.Texture, .(0, 0, 16, 16), 82);
		}

		// Combos UI
		{
			// Progress bar
			{
				let barY = 10;

				float width = 200;

				let barXPos = UI_SCREEN_WIDTH - width;
				let barYPos = barY;

				let barWidth = width;
				let barHeight = 44 / 2;

				let cornerWidth = 0;

				m_ProgressBarTimer = Math.Lerp(m_ProgressBarTimer, (float)m_State.ComboTimer.ElapsedSeconds, Raylib.GetFrameTime() * 15.0f);

				let barInnerPadding = 2;
				let barInnerWidth = (int)Math.Lerp(0, width - barInnerPadding, (m_ProgressBarTimer / m_State.MaxComboTimerTime));

				let triangleX = barXPos;
				Raylib.DrawRectangleRec(.(barXPos + cornerWidth, barYPos, barWidth - cornerWidth, barHeight), .Black);
				Raylib.DrawTriangle(.(triangleX, barYPos), .(triangleX + cornerWidth, barYPos + barHeight), .(triangleX + cornerWidth, barYPos), .Black);

				// Inner
				// let innerRec = Rectangle((barXPos + barInnerPadding) + barInnerWidth, barYPos + barInnerPadding, width - (barInnerPadding * 2) - barInnerWidth, barHeight - (barInnerPadding * 2));
				let innerRec = Rectangle(barXPos + cornerWidth + barInnerPadding, barYPos + barInnerPadding, width - (barInnerPadding * 2) - cornerWidth, barHeight - (barInnerPadding * 2));
				let innerColor = m_State.DecrementingCombo ? Color(125, 125, 125, 255) : Color.White;
				Raylib.DrawRectangleGradientEx(innerRec, innerColor, innerColor, innerColor, innerColor);

				Raylib.DrawRectangleRec(.(barXPos + barInnerPadding + cornerWidth, barYPos + barInnerPadding, barInnerWidth - cornerWidth, barHeight - (barInnerPadding * 2)), .Black);
			}

			// Combo Mult
			if (m_State.ComboMult > 1)
			{
				let str = scope $"Combo: x{m_State.ComboMult}";

				let multXPos = (int32)UI_SCREEN_WIDTH - Raylib.MeasureText(str, 20) - 4;
				let multYPos = 36;

				Raylib.DrawText(str, multXPos - 2, multYPos + 2, 20, .Shadow);
				Raylib.DrawText(str, multXPos, multYPos, 20, .White);
			}
		}

		// Bottom right
		{
			void drawSideThing(String text, int32 timerWidth, int32 timerY, Color bgColor)
			{
				let fontSize = 10;
				let textPadding = 2;

				let timerHeight = fontSize + textPadding;

				let cornerWidth = 12;

				let timerX = (int32)UI_SCREEN_WIDTH - timerWidth;

				Raylib.DrawRectangleRec(.(timerX + cornerWidth, timerY, timerWidth - cornerWidth, timerHeight), bgColor);
				Raylib.DrawTriangle(.(timerX, timerY), .(timerX + cornerWidth, timerY + timerHeight), .(timerX + cornerWidth, timerY), bgColor);

				Raylib.DrawText(text, timerX + 4 + cornerWidth, timerY + (textPadding / 2), fontSize, Color.White);
			}

			let baseY = UI_SCREEN_HEIGHT + 12;
			// Highscore
			{
				drawSideThing(scope $"Highscore: {m_SessionHighscore.Points} points", 152, (int32)baseY - 56, .Black);
			}
			// Best time
			{
				drawSideThing(scope $"Best time: {timeFormatted(.. scope .(), m_SessionHighscore.BestTimeTimer)}", 140, (int32)baseY - 44, .(25, 25, 25, 255));
			}
			// Best combo
			{
				drawSideThing(scope $"Best combo: {m_SessionHighscore.Combo}", 128, (int32)baseY - 32, .(35, 35, 35, 255));
			}
		}


		// Lives
		{
			for (let i < MAX_LIVES)
			{
				int invI = Math.Abs((int)(i - MAX_LIVES)) - 1;
				bool noHeart = invI > (int)m_State.Lives - 1;

				let heartSrcRec = Rectangle(noHeart ? 11 : 0, 0, 11, 10);
				let heartDestRec = Rectangle(6 + ((21 + -1) * invI), UI_SCREEN_HEIGHT - 28, 11 * 2, 10 * 2);

				Raylib.DrawTexturePro(Assets.Textures.Heart.Texture, heartSrcRec, heartDestRec - .(2, -2, 0, 0), .Zero, 0, .Shadow);
				Raylib.DrawTexturePro(Assets.Textures.Heart.Texture, heartSrcRec, heartDestRec, .Zero, 0, .White);
			}
		}

		// Raylib.DrawCircleV(GetMousePosition(), 4, .Red);
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
		Rectangle boardRec = .(GetBoardPos().x, GetBoardPos().y, GetBoardSize().x, GetBoardSize().y);

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
					Raylib.DrawRectangleRec(.(GetBoardPos().x + (x * (TILE_SIZE + TILE_SPACING)), GetBoardPos().y + (y * (TILE_SIZE + TILE_SPACING)), TILE_SIZE, TILE_SIZE), .(192, 204, 216, 255));
				}
			}
		}

		// Board tiles
		renderBoardTiles();

		// Board cursor frame
		if (m_State.State == .Game)
		{
			if (GetBoardMouseCoords().x >= 0 && GetBoardMouseCoords().y >= 0
				&& GetBoardMouseCoords().x < m_Board.Width && GetBoardMouseCoords().y < m_Board.Height)
			Raylib.DrawTexture(Assets.Textures.Frame.Texture, (int32)(GetBoardMouseCoords().x * (TILE_SIZE + TILE_SPACING) - 1), (int32)(GetBoardMouseCoords().y * (TILE_SIZE + TILE_SPACING) - 1), Color.White);
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
			let type = m_State.TileType;

			if ((x + y) % 2 == 0)
			{
				Raylib.DrawTextureRec(Assets.Textures.Tiles.Texture, .(0, 18 * type, 18, 18), .(x * (17) - 1, y * 17 - 1), Color.White);
			}
			else
			{
				Raylib.DrawTextureRec(Assets.Textures.Tiles.Texture, .(18, 18 * type, 18, 18), .(x * (17) - 1, y * 17 - 1), Color.White);
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

		void drawMineTile(int x, int y)
		{
			let drawPos = getTileDrawPosCenter(x, y);

			Raylib.DrawRectangleRec(.(x * (TILE_SIZE + TILE_SPACING), y * (TILE_SIZE + TILE_SPACING), TILE_SIZE, TILE_SIZE), .(210, 45, 31, 255));
			// Raylib.DrawCircleV(drawPos, (TILE_SIZE * 0.5f) - 4, Color.Black);
			Raylib.DrawTextureRec(Assets.Textures.Bomb.Texture, .(0, 0, 16, 16), .(x * (TILE_SIZE + TILE_SPACING), y * (TILE_SIZE + TILE_SPACING)) - .(0, 0), .White);
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
					drawClosedTile(x, y);
					drawCrossedOutTile(x, y);
				}
				else if (m_State.Tiles[x, y] == .Opened)
				{
					if (m_State.Mines[x, y])
					{
						drawMineTile(x, y);
					}
					else if (m_State.Numbers[x, y] > 0) // Draw number tile if greater than 0
					{
						drawNumberTile(drawPos, x, y);
					}
				}

				// if (m_State.Mines[x, y])
				// drawMineTile(x, y);
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
			drawRecAtTile(GetBoardMouseCoords().x, GetBoardMouseCoords().y, -1, -1);
			drawRecAtTile(GetBoardMouseCoords().x, GetBoardMouseCoords().y, -1, 0);
			drawRecAtTile(GetBoardMouseCoords().x, GetBoardMouseCoords().y, 1, 0);
			drawRecAtTile(GetBoardMouseCoords().x, GetBoardMouseCoords().y, 1, -1);
			drawRecAtTile(GetBoardMouseCoords().x, GetBoardMouseCoords().y, 0, -1);
			drawRecAtTile(GetBoardMouseCoords().x, GetBoardMouseCoords().y, 0, 1);
			drawRecAtTile(GetBoardMouseCoords().x, GetBoardMouseCoords().y, -1, 1);
			drawRecAtTile(GetBoardMouseCoords().x, GetBoardMouseCoords().y, 1, 1);
		}
	}
}