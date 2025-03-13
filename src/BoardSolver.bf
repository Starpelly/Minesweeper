using System.Collections;
namespace Minesweeper;

extension Game
{
	void SOLVER_revealCell(int x, int y)
	{
		if (x < 0 || y < 0 || x >= m_Board.Width || y >= m_Board.Height || m_State.Tiles[x, y] != .Closed) return;

		m_State.Tiles[x, y] = .Opened;
		if (m_State.Numbers[x, y] == 0)
		{
			for (int d = 0; d < 8; d++)
			{
			    SOLVER_revealCell(x + m_TileDX[d], y + m_TileDY[d]);
			}
		}
	}

	void SOLVER_flagCell(int x, int y)
	{
		if (m_State.Tiles[x, y] == .Closed)
		{
			m_State.Tiles[x, y] = .Flagged;
		}
	}

	bool SOLVER_makeDeterministicMove()
	{
		List<(int, int)> unrevealedTiles = scope .();

	    bool moved = false;
	    for (int x = 0; x < m_Board.Width; x++)
		{
	        for (int y = 0; y < m_Board.Height; y++)
			{
	            if (m_State.Tiles[x, y] != .Opened || m_State.Mines[x, y]) continue;

				unrevealedTiles.Clear();

	            int unrevealedCount = 0, flaggedCount = 0;

	            for (int d = 0; d < 8; ++d)
				{
	                int nx = x + m_TileDX[d], ny = y + m_TileDY[d];
	                if (nx >= 0 && ny >= 0 && nx < m_Board.Width && ny < m_Board.Height)
					{
	                    if (m_State.Tiles[nx, ny] == .Closed) {
	                        unrevealedTiles.Add((nx, ny));
	                        unrevealedCount++;
	                    }
	                    if (m_State.Tiles[nx, ny] == .Flagged) {
	                        flaggedCount++;
							unrevealedCount++;
	                    }
	                }
	            }

	            // If the number of unrevealed tiles matches the mine count, flag them
	            if (unrevealedCount > 0 && m_State.Numbers[x, y] == unrevealedCount)
				{
	                for (let coords in unrevealedTiles)
					{
						SOLVER_flagCell(coords.0, coords.1);
	                    moved = true;
	                }
	            }

	            // If all mines around are flagged, reveal other safe tiles
	            if (flaggedCount == m_State.Numbers[x, y])
				{
	                for (let coords in unrevealedTiles)
					{
						SOLVER_revealCell(coords.0, coords.1);
	                    moved = true;
	                }
	            }
	        }
	    }
	    return moved;
	}
}