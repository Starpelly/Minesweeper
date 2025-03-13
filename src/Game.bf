using System;
using System.Collections;
using System.Diagnostics;
using RaylibBeef;

namespace Minesweeper;

[Reflect(.DefaultConstructor), AlwaysInclude(AssumeInstantiated=true)]
class Game : Scene
{
	// ---------
	// Constants
	// ---------

	private static float UI_SCALE => 2.0f;
	private static float UI_SCREEN_WIDTH => 1280.0f / UI_SCALE;
	private static float UI_SCREEN_HEIGHT => 720.0f / UI_SCALE;

	private static float VIEWPORT_SCALE => (float)SCREEN_WIDTH / (float)BASE_SCREEN_WIDTH;

	private static float BASE_CAMERA_ZOOM => 4.0f;

	private let TILE_COLOR_0 = Color(38, 92, 66, 255);
	private let TILE_COLOR_1 = Color(99, 199, 77, 255);

	private const uint32 TILE_SIZE = 16;
	private const uint32 TILE_SPACING = 1;
	private const uint32 LINE_WIDTH = 1;

	private static int BG_CHECKER_SIZE => (int)(48 * VIEWPORT_SCALE);

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

	private const bool NO_GUESSING = true;

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

	// UI Transitions
	private const float UI_TITLE_TO_GAME_FADE_LENGTH = 0.35f;
	private const float UI_GAME_SLIDE_IN_LENGTH = 0.55f;

	// Directions for neighbor checks (8 adjacent cells)
	private static readonly int[] m_TileDX = new .(-1, -1, -1, 0, 0, 1, 1, 1) ~ delete _;
	private static readonly int[] m_TileDY = new .(-1, 0, 1, -1, 1, -1, 0, 1) ~ delete _;

	// -----
	// Enums
	// -----

	private enum TileState
	{
		Closed,
		Opened,
		Flagged,
		NoMine,
	}

	private enum GameState
	{
		Game,
		Lose,
		Win,
		GameOver
	}

	private enum DrawTextSize
	{
		Big,
		Small
	}

	private enum DrawTextType
	{
		Outline,
		NoOutline,
		Shadow
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

	private List<(int, int)> m_MinesToExplode = new .() ~ delete _;
	private float m_MinesToExplodeTimer = 0.0f;

	private float m_SceneTime = 0.0f;

	private enum UIState
	{
		Title,
		Game
	}

	private UIState m_UIState = .Title;

	private struct Cloud
	{
		public Vector2 Position;
		public float Speed;
	}
	private List<Cloud> m_BGClouds = new .() ~ delete _;

	// -----------------
	// Private accessors
	// -----------------

	private Vector2 GetBoardSize() => .(m_Board.Width * (TILE_SIZE + TILE_SPACING), m_Board.Height * (TILE_SIZE + TILE_SPACING));
	private Vector2 GetBoardPos() => .Zero;

	private Vector2I GetBoardMouseCoords()
	{
		let tempCam = Camera2D(m_Camera.offset, m_Camera.target, m_Camera.rotation, m_Camera.zoom * (SCREEN_WIDTH / 1280.0f));
		let mp = Raylib.GetScreenToWorld2D(GetMousePosition(), tempCam) - GetBoardPos();
		var ret = mp / (TILE_SIZE + TILE_SPACING);

		if (mp.x < 0)
			ret.x -= 1;
		if (mp.y < 0)
			ret.y -= 1;

		return ret;
	}

	private bool MouseHoveringBoard()
	{
		let mp = GetBoardMouseCoords();
		return mp.x >= 0 && mp.y >= 0 && mp.x < m_Board.Width && mp.y < m_Board.Height;
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

		m_UIRenderTexture = Raylib.LoadRenderTexture((int32)UI_SCREEN_WIDTH, (int32)UI_SCREEN_HEIGHT);

		// Create clouds
		{
			let cloudWidth = Assets.Textures.Cloud.Texture.width;
			let cloudHeight = Assets.Textures.Cloud.Texture.height;

			for (let i < 15)
			{
				let cloudPos = Vector2(
					Random.Next(-(cloudWidth / 2), BASE_SCREEN_WIDTH - (cloudWidth / 2)),
					Random.Next(-(cloudHeight / 2), BASE_SCREEN_HEIGHT - (cloudHeight / 2))
					);

				m_BGClouds.Add(Cloud()
					{
						Position = cloudPos,
						Speed = Random.Next(1, 4)
					});
			}
		}

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

		let newBoardWidth = (int)Math.Clamp(m_State.NextColumnCount, DEFAULT_BOARD_WIDTH, 30);
		let newBoardHeight = (int)Math.Clamp(m_State.NextRowCount, DEFAULT_BOARD_HEIGHT, 16);

		let maxMinesCount = (uint)Math.Floor((newBoardWidth * newBoardHeight) * 0.3f); // 30% of the total board area
		let newMineCount = Math.Clamp(startMineCount, startMineCount, maxMinesCount);

		// Console.WriteLine(scope $"Max Mine Count: {maxMinesCount}");

		let newBoard = Board()
		{
			Width = newBoardWidth,
			Height = newBoardHeight,
			Mines = (uint)newMineCount,
		};
		Remake(newBoard, false);
	}

	public void OnMineExplode(bool start)
	{
		Raylib.PlaySound(Assets.Sounds.Boom.Sound);
		ShakeCamera((start) ? 45 : 24 / 10.0f, 8, 0.6f);
		CreateParticle(new ExplosionFlashParticle((start) ? 240 : 15));
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

		for (var mine in ref m_State.Mines)
		{
			mine = false;
		}
		for (var tile in ref m_State.Tiles)
		{
			tile = .Closed;
		}
		for (var number in ref m_State.Numbers)
		{
			number = 0;
		}
		m_State.MineCount = 0;
		m_State.FlagCount = 0;

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

		// Console.WriteLine(totalNumbers);
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

		if (m_State.Tiles[x, y] == .Closed)
		{
			m_State.Tiles[x, y] = .Opened;

			let tileColor = ((x + y) % 2 == 0) ? TILE_COLOR_0 : TILE_COLOR_1;
			CreateParticle(new OpenedTileParticle(.(x * (TILE_SIZE + TILE_SPACING), y * (TILE_SIZE + TILE_SPACING)), tileColor));
			ShakeCamera(1f, 4, 2);

			Raylib.PlaySound(Assets.Sounds.Click.Sound);
		}

		// Lose if we opened a mine
		if (m_State.Tiles[x, y] == .Opened && m_State.Mines[x, y] == true)
		{
			OnMineExplode(true);
			m_MinesToExplodeTimer = 0.0f;

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
					if (m_State.Mines[bx, by] && m_State.Tiles[bx, by] != .Flagged)
					{
						m_State.Tiles[bx, by] = .Opened;
						// m_MinesToExplode.Add((bx, by));
					}
					else
					{
						if (!m_State.Mines[bx, by] && m_State.Tiles[bx, by] == .Flagged)
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
							Raylib.SetSoundVolume(Assets.Sounds.ClearArea.Sound, 0.35f);
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

		Raylib.SetSoundVolume(Assets.Sounds.Win.Sound, 0.5f);
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
					if (m_State.Tiles[k, l] == .Flagged)
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

		// Raylib.PlaySound(Assets.Sounds.ClearArea.Sound);
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
					if (m_State.Tiles[k, l] == .Closed || m_State.Tiles[k, l] == .Flagged)
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

		let lastFlagState = m_State.Tiles[x, y] == .Flagged;

		if (allowUnflag)
		{
			m_State.Tiles[x, y] = m_State.Tiles[x, y] == .Flagged ? 0 : .Flagged;
		}
		else
		{
			m_State.Tiles[x, y] = .Flagged;

			if (lastFlagState && m_State.Tiles[x, y] == .Flagged) return;
		}

		if (m_State.Tiles[x, y] == .Flagged != lastFlagState)
			Raylib.PlaySound(Assets.Sounds.Flag.Sound);

		if (m_State.Tiles[x, y] == .Flagged)
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

		if (m_State.WaitingForFirstClick)
		{
			m_State.IsPlaying = true;
			m_State.WaitingForFirstClick = false;

			if (NO_GUESSING)
			{
				bool Solve()
				{
					SOLVER_revealCell(x, y);
	
					while (SOLVER_makeDeterministicMove())
					{
					}
	
					// Check if board is fully solved
					bool solved = true;
					for (int x = 0; x < m_Board.Width; x++)
					{
						for (int y = 0; y < m_Board.Height; y++)
						{
						    if (m_State.Tiles[x, y] == .Closed && !m_State.Mines[x, y])
							{
						        solved = false;
						        break;
						    }
						}
						if (!solved) break;
					}
	
					if (solved)
					{
						Console.ForegroundColor = .Green;
						Console.WriteLine("Game solved using a no-guess strategy!");
					}
					else
					{
						Console.ForegroundColor = .Red;
						Console.WriteLine("Unsolvable without guessing! Algorithm got stuck...");
					}
					Console.ResetColor();
	
					return solved;
				}
	
				bool solved = false;
				while (!solved)
				{
					GenerateMines(x, y);
					solved = Solve();
				}
	
				// Hide all tiles again
				for (var tile in ref m_State.Tiles)
				{
					tile = .Closed;
				}
			}
			else
			{
				if (m_State.WaitingForFirstClick)
				{
					GenerateMines(x, y);
				}
			}

			m_State.SessionTimer.Start();
			m_State.ComboTimer.Start();
			m_State.MineTimer.Start();
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

		if (m_State.Tiles[x, y] == .Closed || m_State.Tiles[x, y] == .Flagged)
		{
			Flag(x, y);
		}
		else
		{
			if (m_State.Numbers[x, y] > 0)
			{
				ChordMines(x, y);
			}
			else
			{
				Raylib.PlaySound(Assets.Sounds.Tap.Sound);
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

						if (/*m_State.Mines[k, l] == true &&*/ m_State.Tiles[k, l] == .Flagged)
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

	private Vector2I m_LastHoveringTile = .(0, 0);
	private float m_TimeSinceUIStateChange = 0.0f;
	private bool m_ChangingUIState = false;

	public override void Update()
	{
		m_SceneTime += Raylib.GetFrameTime();
		m_TimeSinceUIStateChange += Raylib.GetFrameTime();

		// Update background clouds
		{
			let cloudWidth = Assets.Textures.Cloud.Texture.width;
			let cloudHeight = Assets.Textures.Cloud.Texture.height;

			for (var cloud in ref m_BGClouds)
			{
				cloud.Position.x -= (cloud.Speed * 10) * Raylib.GetFrameTime();

				if (cloud.Position.x < -cloudWidth)
				{
					cloud.Position.y = Random.Next(-(cloudHeight / 2), BASE_SCREEN_HEIGHT - (cloudHeight / 2));
					cloud.Position.x = BASE_SCREEN_WIDTH;
				}
			}
		}

		if (m_UIState == .Title)
		{
			if (Raylib.IsMouseButtonPressed(.MOUSE_BUTTON_LEFT) && !m_ChangingUIState)
			{
				m_TimeSinceUIStateChange = 0.0f;
				m_ChangingUIState = true;
			}

			if (m_ChangingUIState)
			{
				if (m_TimeSinceUIStateChange >= UI_TITLE_TO_GAME_FADE_LENGTH)
				{
					m_TimeSinceUIStateChange = 0.0f;
					m_UIState = .Game;
				}
			}
		}
		else if (m_UIState == .Game)
		{
			if (m_TimeSinceUIStateChange >= UI_GAME_SLIDE_IN_LENGTH)
			{
				m_ChangingUIState = false;
			}

			m_MinesToExplodeTimer += Raylib.GetFrameTime();
			if (m_MinesToExplodeTimer >= 0.08f && m_MinesToExplode.Count > 0)
			{
				let mine = m_MinesToExplode[0];
				m_State.Tiles[mine.0, mine.1] = .Opened;

				OnMineExplode(false);

				m_MinesToExplode.RemoveAt(0);
				m_MinesToExplodeTimer = 0.0f;
			}

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
			let baseBoardSize = GetBoardSize() * baseZoom;

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

			if (m_Board.Width > 15 || m_Board.Height > 8)
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
				m_TargetCameraZoom = 0.375f;
			}
			if (m_Board.Width > 42 || m_Board.Height > 21)
			{
				m_TargetCameraZoom = 0.25f;
			}

			m_Camera.zoom = Math.Lerp(m_Camera.zoom, (m_TargetCameraZoom * BASE_CAMERA_ZOOM), Raylib.GetFrameTime() * 18.0f);
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

			if (MouseHoveringBoard() && GetBoardMouseCoords() != m_LastHoveringTile && m_State.State == .Game)
			{
				/*
				Raylib.StopSound(Assets.Sounds.Hover.Sound);
				Raylib.SetSoundVolume(Assets.Sounds.Hover.Sound, 0.25f);
				Raylib.PlaySound(Assets.Sounds.Hover.Sound);
				*/
			}
			m_LastHoveringTile = GetBoardMouseCoords();

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
			if (m_UIState == .Game)
			{
				if (m_State.MineTimer.Elapsed.TotalSeconds >= m_State.SecondsToNewMine)
				{
					m_State.StartMineAdd++;
					m_State.MineTimer.Restart();
				}
			}

			// Update combo timer
			if (m_State.State == .Game && m_UIState == .Game)
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
	}

	public void RenderUIToTexture()
	{
		Raylib.BeginTextureMode(m_UIRenderTexture);
		Raylib.ClearBackground(.(0, 0, 0, 0));
		renderUI();
		Raylib.EndTextureMode();
	}

	public override void Render()
	{
		// Render game shit
		{
			renderBackground();

			var shakeInf = m_CamShakeInfluence;
			/*if (shakeInf.x < Raymath.EPSILON)
				shakeInf.x = 0.0f;
			if (shakeInf.y < Raymath.EPSILON)
				shakeInf.y = 0.0f;
			*/

			let transitionVec = m_ChangingUIState ? Vector2(0, Math.Lerp(-400, 0, GetGameTransitionEx())) : Vector2.Zero;

			let drawCamera = Camera2D(m_Camera.offset, m_Camera.target + shakeInf + transitionVec, m_Camera.rotation, m_Camera.zoom * (SCREEN_WIDTH / 1280.0f));
			Raylib.BeginMode2D(drawCamera);
			{
				if (m_UIState == .Game)
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
			let youWinSize = 30 * (int32)UI_SCALE;
			let txtMeasure = Raylib.MeasureText(youWinTxt, youWinSize);

			Raylib.DrawText(youWinTxt, (int32)(SCREEN_WIDTH / 2) - (txtMeasure / 2), (int32)(SCREEN_HEIGHT / 2) - (youWinSize / 2), youWinSize, Color.White);
		}
		else if (m_State.State == .GameOver)
		{
			Raylib.DrawRectangleRec(.(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT), .(255, 0, 0, 120));

			let youWinTxt = "Game Over!!! :(";
			let youWinSize = 30 * (int32)UI_SCALE;
			let txtMeasure = Raylib.MeasureText(youWinTxt, youWinSize);

			if (m_State.NextBoardTimer.Elapsed.TotalSeconds >= TIME_BETWEEN_BOARDS_GAMEOVER)
			{
				let str = "(Left Click to restart)";
				let clTxtMeasure = Raylib.MeasureText(str, 10 * (int32)UI_SCALE);
				Raylib.DrawText(str, (int32)(SCREEN_WIDTH / 2) - (clTxtMeasure / 2), (int32)(SCREEN_HEIGHT / 2) + 20, 10 * (int32)UI_SCALE, .White);
			}

			Raylib.DrawText(youWinTxt, (int32)(SCREEN_WIDTH / 2) - (txtMeasure / 2), (int32)(SCREEN_HEIGHT / 2) - (youWinSize / 2), youWinSize, Color.White);
		}

		// Screen fade
		if (m_SceneTime < 0.5f)
			Raylib.DrawRectangle(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT, .(Color.ScreenFade.r, Color.ScreenFade.g, Color.ScreenFade.b, (uint8)Math.Lerp(255, 0, Math.Normalize(m_SceneTime, 0, 0.5f))));
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

	private float GetTextSize(DrawTextSize size)
	{
		switch (size)
		{
		case .Big: return 24;
		case .Small: return 12;
		}
	}

	private void DrawText(String text, Vector2 pos, DrawTextSize size, DrawTextType type, uint8 alpha = 255)
	{
		DrawTextColored(text, pos, size, type, .(255, 255, 255, alpha));
	}

	private void DrawTextColored(String text, Vector2 pos, DrawTextSize size, DrawTextType type, Color color)
	{
		let txtSize = GetTextSize(size);

		if (type == .Outline)
			Raylib.DrawTextEx(Assets.Fonts.NokiaOutline.Font, text, pos, txtSize, 0, .(Color.DarkOutline.r, Color.DarkOutline.g, Color.DarkOutline.b, color.a));
		else if (type == .Shadow)
			Raylib.DrawTextEx(Assets.Fonts.Nokia.Font, text, pos - .(2, -2), txtSize, 0, .(Color.Shadow.r, Color.Shadow.g, Color.Shadow.b, color.a));
		Raylib.DrawTextEx(Assets.Fonts.Nokia.Font, text, pos, txtSize, 0, color);
	}

	private Vector2 MeasureText(String text, DrawTextSize size)
	{
		return Raylib.MeasureTextEx(Assets.Fonts.Nokia.Font, text, GetTextSize(size), 0);
	}

	private float GetGameTransitionEx()
	{
		return EasingFunctions.OutExpo(Math.Normalize(m_TimeSinceUIStateChange, 0, UI_GAME_SLIDE_IN_LENGTH, true));
	}

	private void renderUI()
	{
		if (m_UIState == .Title)
		{
			let uiCam = Camera2D(.Zero, .(-UI_SCREEN_WIDTH / 2, -UI_SCREEN_HEIGHT / 2), 0, 1);

			Raylib.BeginMode2D(uiCam);
			{
				let uiAlpha = m_ChangingUIState ?
					(uint8)Math.Lerp(255, 0, Math.Normalize(m_TimeSinceUIStateChange, 0, UI_TITLE_TO_GAME_FADE_LENGTH, true))
					: 255;

				let textureLogo = Assets.Textures.Logo.Texture;
				Raylib.DrawTextureEx(textureLogo, .(-textureLogo.width / 2, -textureLogo.height / 2) - .(0, 80), 0, 1, .(255, 255, 255, uiAlpha));

				let txt = "Click to start!";
				let txtSize = 12 * 2;
				let txtPos = Vector2(-Raylib.MeasureTextEx(Assets.Fonts.Nokia.Font, txt, txtSize, 0).x / 2, 80);
				DrawText(txt, txtPos, .Big, .Outline, uiAlpha);
			}
			Raylib.EndMode2D();
		}
		else if (m_UIState == .Game)
		{
			let uiCamY = Math.Lerp(-420, 0, GetGameTransitionEx());

			let uiCam = Camera2D(.Zero, .(0, uiCamY), 0, 1);

			Raylib.BeginMode2D(uiCam);
			{
				void timeFormatted(String outStr, Stopwatch stopwatch)
				{
					outStr.Append(scope $"{(int)stopwatch.Elapsed.TotalHours:D2}:{stopwatch.Elapsed.Minutes:D2}:{stopwatch.Elapsed.Seconds:D2}'{stopwatch.Elapsed.Milliseconds:D3}");
				}

				void drawAngledSideBarLeft(Vector2 position, Vector2 size, Color color)
				{
					let cornerWidth = size.y;
					let triangleX = (position.x + size.x) - cornerWidth;

					Raylib.DrawRectangleRec(.(position.x, position.y, size.x - cornerWidth, size.y), color);

					Raylib.DrawTriangle(.(triangleX, position.y), .(triangleX, position.y + size.y), .(triangleX + cornerWidth, position.y), color);
				}

				void drawAngledSideBarRight(Vector2 position, Vector2 size, Color bgColor)
				{
					let cornerWidth = size.y;

					let timerX = (int32)UI_SCREEN_WIDTH - size.x - position.x;

					Raylib.DrawRectangleRec(.(timerX + cornerWidth, position.y, size.x - cornerWidth, size.y), bgColor);
					Raylib.DrawTriangle(.(timerX, position.y), .(timerX + cornerWidth, position.y + size.y), .(timerX + cornerWidth, position.y), bgColor);
				}

				// Top left
				{
					void drawSideThingLeft(String text, int32 timerWidth, int32 timerY, DrawTextSize size, Color bgColor)
					{
						var timerY;
						timerY -= 8;

						let textPadding = 0;

						let timerHeight = GetTextSize(size) + textPadding;

						let timerX = 0;

						drawAngledSideBarLeft(.(timerX, timerY), .(timerWidth, timerHeight), bgColor);
						DrawText(text, .(timerX + 4, timerY + (textPadding / 2)), size, .Outline);
					}

					// Points
					{
						drawSideThingLeft(scope $"{m_State.Points} points", 196, 8, .Big, .Black);
					}
					// Total Timer
					{
						drawSideThingLeft(scope $"Time: {timeFormatted(.. scope .(), m_State.SessionTimer)}", 172, 32, .Small, .(25, 25, 25, 255));
					}
				}

				// Counters
				{
					let barHeight = 30;
					void drawCounter(String text, float width, Texture2D texture, Rectangle textureRegion, int32 posY, int32 iconOffsetX)
					{
						var posY;
						posY -= 8;

						let textOffsetX = 32 + 2;

						let position = Vector2(textOffsetX, posY + 6);

						// drawAngledSideBar(.(0, position.y - 6), .(width, barHeight), .(35, 35, 35, 255));

						// Raylib.DrawRectangleRec(.(0, posY, 120 + 4, 32), .(25, 25, 25, 150));
						// Raylib.DrawTexturePro(texture, textureRegion, .(0 - 2, posY + 2, 32, 32), .Zero, 0, .Shadow);
						Raylib.DrawTexturePro(texture, textureRegion, .(iconOffsetX, posY, 32, 32), .Zero, 0, .White);

						DrawText(text, .(textOffsetX, posY + 6), .Big, .Outline);
					}

					drawCounter(m_State.MineCount.ToString(.. scope .()), 156, Assets.Textures.Bomb.Texture, .(0, 0, 16, 16), 48, 0);
					drawCounter(((int)(m_State.MineCount - m_State.FlagCount)).ToString(.. scope .()), 126, Assets.Textures.Flags.Texture, .(0, 0, 16, 16), 48 + barHeight, -1);
				}

				// Combos UI
				{
					// Progress bar
					{
						let barY = 8;

						float width = 195;

						let barXPos = UI_SCREEN_WIDTH - width;
						let barYPos = barY;

						let barWidth = width;
						let barHeight = 44 / 2;

						let cornerWidth = 0;

						m_ProgressBarTimer = Math.Lerp(m_ProgressBarTimer, (float)m_State.ComboTimer.ElapsedSeconds, Raylib.GetFrameTime() * 15.0f);

						let barInnerPadding = 2;
						let barInnerWidth = (int)Math.Lerp(0, width - barInnerPadding, (m_ProgressBarTimer / m_State.MaxComboTimerTime));

						let triangleX = barXPos;
						Raylib.DrawRectangleRec(.(barXPos + cornerWidth, barYPos, barWidth - cornerWidth, barHeight), .DarkOutline);
						Raylib.DrawTriangle(.(triangleX, barYPos), .(triangleX + cornerWidth, barYPos + barHeight), .(triangleX + cornerWidth, barYPos), .DarkOutline);

						// Inner
						// let innerRec = Rectangle((barXPos + barInnerPadding) + barInnerWidth, barYPos + barInnerPadding, width - (barInnerPadding * 2) - barInnerWidth, barHeight - (barInnerPadding * 2));
						let innerRec = Rectangle(barXPos + cornerWidth + barInnerPadding, barYPos + barInnerPadding, width - (barInnerPadding * 2) - cornerWidth, barHeight - (barInnerPadding * 2));
						let innerColor = m_State.DecrementingCombo ? Color(125, 125, 125, 255) : Color.White;
						Raylib.DrawRectangleGradientEx(innerRec, innerColor, innerColor, innerColor, innerColor);

						Raylib.DrawRectangleRec(.(barXPos + barInnerPadding + cornerWidth, barYPos + barInnerPadding, barInnerWidth - cornerWidth, barHeight - (barInnerPadding * 2)), .DarkOutline);
					}

					// Combo Mult
					if (m_State.ComboMult > 1)
					{
						let str = scope $"Combo: x{m_State.ComboMult}";

						let multXPos = (int32)UI_SCREEN_WIDTH - MeasureText(str, .Big).x - 4;
						let multYPos = 30;

						// drawAngledSideBarRight(.(0, multYPos), .(194, 20 + 4), .Black);

						DrawText(str, .(multXPos, multYPos), .Big, .Outline);
					}
				}

				// Bottom right
				{
					void drawSideThing(String text, int32 timerWidth, int32 timerY, Color bgColor)
					{
						var timerY;
						timerY += 8;

						let fontSize = 10;
						let textPadding = 2;

						let timerHeight = fontSize + textPadding;

						let cornerWidth = 12;

						let timerX = (int32)UI_SCREEN_WIDTH - timerWidth;

						// Raylib.DrawRectangleRec(.(timerX + cornerWidth, timerY, timerWidth - cornerWidth, timerHeight), bgColor);
						// Raylib.DrawTriangle(.(timerX, timerY), .(timerX + cornerWidth, timerY + timerHeight), .(timerX + cornerWidth, timerY), bgColor);

						drawAngledSideBarRight(.(0, timerY), .(timerWidth, timerHeight), bgColor);

						// Raylib.DrawText(text, timerX + 4 + cornerWidth, timerY + (textPadding / 2), fontSize, Color.White);
						DrawText(text, .(timerX + 4 + cornerWidth, timerY + (textPadding / 2) - 1), .Small, .Outline);
					}

					let baseY = UI_SCREEN_HEIGHT + 12;
					// Highscore
					{
						drawSideThing(scope $"Highscore: {m_SessionHighscore.Points} points", 172, (int32)baseY - 56, .Black);
					}
					// Best time
					{
						drawSideThing(scope $"Best time: {timeFormatted(.. scope .(), m_SessionHighscore.BestTimeTimer)}", 160, (int32)baseY - 44, .(25, 25, 25, 255));
					}
					// Best combo
					{
						drawSideThing(scope $"Best combo: {m_SessionHighscore.Combo}", 148, (int32)baseY - 32, .(35, 35, 35, 255));
					}
				}


				// Lives
				{
					// drawAngledSideBarLeft(.(0, UI_SCREEN_HEIGHT - 32), .(170, 32), .(25, 25, 25, 255));

					for (let i < MAX_LIVES)
					{
						int invI = Math.Abs((int)(i - MAX_LIVES)) - 1;
						bool noHeart = invI > (int)m_State.Lives - 1;

						let heartSrcRec = Rectangle(noHeart ? 11 : 0, 0, 11, 10);
						let heartDestRec = Rectangle(6 + ((21 + -1) * invI), UI_SCREEN_HEIGHT - 26, 11 * 2, 10 * 2);

						// Raylib.DrawTexturePro(Assets.Textures.Heart.Texture, heartSrcRec, heartDestRec - .(2, -2, 0, 0), .Zero, 0, .Shadow);
						Raylib.DrawTexturePro(Assets.Textures.Heart.Texture, heartSrcRec, heartDestRec, .Zero, 0, .White);
					}
				}
			}
			Raylib.EndMode2D();
			// Raylib.DrawCircleV(GetMousePosition(), 4, .Red);
		}
	}

	private Vector2 m_BGOffset;

	private void renderBackground()
	{
		let bgWidth = SCREEN_WIDTH;
		let bgHeight = SCREEN_HEIGHT;

		let clearColor = Color(90, 105, 136, 255);
		Raylib.ClearBackground(clearColor);

		var checkerOffsetX = (float)Raylib.GetTime() * 10;
		var checkerOffsetY = (float)Raylib.GetTime() * 0;

		var newBGOffset = Vector2(GetMousePosition().x * 0.01f, GetMousePosition().y * 0.01f);
		m_BGOffset = .(Math.Lerp(m_BGOffset.x, newBGOffset.x, Raylib.GetFrameTime() * 5.0f), Math.Lerp(m_BGOffset.y, newBGOffset.y, Raylib.GetFrameTime() * 5.0f));

		checkerOffsetX += m_BGOffset.x;
		checkerOffsetY += m_BGOffset.y;

		let checkerBoardOffset = Vector2(Math.Repeat(checkerOffsetX, BG_CHECKER_SIZE * 2), Math.Repeat(checkerOffsetY, BG_CHECKER_SIZE * 2));
		for (let y < (bgHeight / BG_CHECKER_SIZE) + 3)
		{
			for (let x < (bgWidth / BG_CHECKER_SIZE) + 3)
			{
				if ((x + y) % 2 == 0)
				{
					let xpos = (x * BG_CHECKER_SIZE) - checkerBoardOffset.x;
					let ypos = (y * BG_CHECKER_SIZE) - checkerBoardOffset.y;

					Raylib.DrawRectangleRec(.(xpos, ypos, BG_CHECKER_SIZE, BG_CHECKER_SIZE), Color(0, 0, 50, 5));
				}
			}
		}

		// Draw clouds
		let bgCam = Camera2D(.Zero, m_BGOffset + (m_CamShakeInfluence * 0.45f), 0, ((float)SCREEN_WIDTH / (float)BASE_SCREEN_WIDTH));
		{
			Raylib.BeginMode2D(bgCam);
			for (let cloud in m_BGClouds)
			{
				Raylib.DrawTextureEx(Assets.Textures.Cloud.Texture, cloud.Position, 0, 1, .(168, 188, 221, 255));
			}
			Raylib.EndMode2D();
		}

		Raylib.DrawRectangleGradientV(0, 0, bgWidth, bgHeight + 120, .(clearColor.r, clearColor.g, clearColor.b, 0), clearColor);
	}

	private void renderBoard()
	{
		Rectangle boardRec = .(GetBoardPos().x, GetBoardPos().y, GetBoardSize().x, GetBoardSize().y);

		// Board shadow
		// Raylib.DrawRectangleRec(boardRec - Rectangle(7, -6, 0, 0), .(0, 0, 0, 40));

		// Board bg
		Raylib.DrawRectangleRec(boardRec, .(93, 105, 129, 255));
		// Raylib.DrawRectangleRec(boardRec, .(192, 204, 216, 255));

		// Board tiles
		{
			for (let x < m_Board.Width)
			{
				for (let y < m_Board.Height)
				{
					// let tilePos = Vector2(GetBoardPos().x + (x * (TILE_SIZE + TILE_SPACING)), GetBoardPos().y + (y * (TILE_SIZE + TILE_SPACING)));
					// let tileColor = ((x + y) % 2) == 0 ? Color(236, 240, 251, 255) : Color(236, 240, 251, 255);

					// if ((x + y) % 2 == 0)
					// Raylib.DrawTexture(Assets.Textures.EmptyTile.Texture, (int32)tilePos.x, (int32)tilePos.y, tileColor);

					Raylib.DrawRectangleRec(.(GetBoardPos().x + (x * (TILE_SIZE + TILE_SPACING)), GetBoardPos().y + (y * (TILE_SIZE + TILE_SPACING)), TILE_SIZE, TILE_SIZE), .(192, 204, 216, 255));
					// Raylib.DrawRectangleRec(.(GetBoardPos().x + (x * (TILE_SIZE + TILE_SPACING)), GetBoardPos().y + (y * (TILE_SIZE + TILE_SPACING)), TILE_SIZE, TILE_SIZE), .(192, 204, 216, 255));
				}
			}
		}

		// Board tiles
		renderBoardTiles();

		// Board cursor frame
		if (m_State.State == .Game && m_UIState == .Game)
		{
			if (MouseHoveringBoard())
			{
				let cursorDrawPos = Vector2(GetBoardMouseCoords().x * (TILE_SIZE + TILE_SPACING) - 1, GetBoardMouseCoords().y * (TILE_SIZE + TILE_SPACING) - 1);
				let tapping = Raylib.IsMouseButtonDown(.MOUSE_BUTTON_LEFT) || Raylib.IsMouseButtonDown(.MOUSE_BUTTON_RIGHT);

				// Raylib.DrawTexture(Assets.Textures.Frame.Texture, (int32)(GetBoardMouseCoords().x * (TILE_SIZE + TILE_SPACING) - 1), (int32)(GetBoardMouseCoords().y * (TILE_SIZE + TILE_SPACING) - 1), Color.White);
				Raylib.DrawTextureRec(
					Assets.Textures.Frame.Texture,
					.(tapping ? 18 : 0, 0, 18, 18),
					cursorDrawPos,
					Color.White);
			}
		}

		// Board outline
		Raylib.DrawRectangleLinesEx(boardRec - Rectangle(1, 1, -1, -1), LINE_WIDTH, .DarkOutline);
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

			// Raylib.DrawText(numStr, ((int32)drawPos.x) - 2, ((int32)drawPos.y) - 4, 8, NUMBER_COLORS[number]);
			DrawTextColored(numStr, .(((int32)drawPos.x) - 3, ((int32)drawPos.y) - 5), .Small, .NoOutline, NUMBER_COLORS[number]);
			// Raylib.DrawTextEx(Assets.Fonts.More15Outline.Font, numStr, .(((int32)drawPos.x) - 5, ((int32)drawPos.y) - 12), 24, 1, .Black);
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
			let closedTileSize = 18;

			let tileColor = ((x + y) % 2 == 0) ? TILE_COLOR_0 : TILE_COLOR_1;

			Raylib.DrawTextureRec(Assets.Textures.Tiles.Texture, .(0, closedTileSize * type, closedTileSize, closedTileSize), .(x * (closedTileSize - 1) - TILE_SPACING, y * (closedTileSize - 1) - TILE_SPACING), tileColor);
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
				else if (m_State.Tiles[x, y] == .Flagged)
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
			for (int d < 8)
			{
				drawRecAtTile(GetBoardMouseCoords().x, GetBoardMouseCoords().y, m_TileDX[d], m_TileDY[d]);
			}
		}
	}
}