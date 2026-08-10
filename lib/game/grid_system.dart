import 'dart:math';
import 'dart:ui';

/// State of a single grid cell.
/// [blocked] cells are permanent interior walls used to shape each level's
/// playfield — the player and enemies can't enter them, and they're
/// excluded from the capture percentage entirely (they were never
/// claimable ground to begin with).
enum CellState { open, claimed, trail, blocked }

/// A simple integer grid coordinate.
class GridPos {
  final int row;
  final int col;

  const GridPos(this.row, this.col);

  @override
  bool operator ==(Object other) =>
      other is GridPos && other.row == row && other.col == col;

  @override
  int get hashCode => row * 100003 + col;
}

/// Owns the capture grid: claimed territory, interior obstacle walls, the
/// active trail, and the flood-fill logic that decides which enclosed
/// pockets get claimed when a trail loop closes.
class GridSystem {
  final int rows;
  final int cols;
  final double cellSize;
  late List<List<CellState>> cells;

  final List<GridPos> _activeTrail = [];

  final int _borderThickness;

  GridSystem({
    required this.rows,
    required this.cols,
    required this.cellSize,
    int borderThickness = 2,
  }) : _borderThickness = borderThickness {
    cells = List.generate(rows, (_) => List.filled(cols, CellState.open));
    _carveBorder(borderThickness);
  }

  /// Reinitializes the grid in place (used between levels / on restart)
  /// so components holding a reference to this instance stay valid.
  /// Call [applyLevelLayout] right after this to shape the new level.
  void reset() {
    _activeTrail.clear();
    cells = List.generate(rows, (_) => List.filled(cols, CellState.open));
    _carveBorder(_borderThickness);
  }

  void _carveBorder(int thickness) {
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final onBorder = r < thickness ||
            c < thickness ||
            r >= rows - thickness ||
            c >= cols - thickness;
        if (onBorder) cells[r][c] = CellState.claimed;
      }
    }
  }

  /// Shapes the interior play area differently depending on level, so the
  /// field isn't just a plain rectangle forever. Picks from 8 shape
  /// families (cycled so every family reappears regularly) and, within
  /// whichever family is chosen, randomizes its parameters — size,
  /// orientation, spacing — using a level-seeded RNG. That means even a
  /// repeat of the same family (e.g. two "pillar field" levels) looks
  /// different in practice, rather than the level literally repeating
  /// itself. Only touches cells that are currently [open] — the border
  /// strip is left alone. Always finishes by forcing open a guaranteed
  /// doorway from the border spawn point into the interior — shape math
  /// can otherwise seal off the interior at a single-cell-wide point that
  /// the discrete grid rounds away to nothing.
  void applyLevelLayout(int level) {
    final rng = Random(level); // deterministic per level, varies with it
    final preset = level % 8;
    switch (preset) {
      case 1:
        _carveCrossShape(rng);
        break;
      case 2:
        _carveDiamondShape(rng);
        break;
      case 3:
        _carveHourglassShape(rng);
        break;
      case 4:
        _carvePillarField(rng);
        break;
      case 5:
        _carveZigzagCorridor(rng);
        break;
      case 6:
        _carveRingGaps(rng);
        break;
      case 7:
        _carveScatteredBlobs(rng, level);
        break;
      default:
        // Plain rectangle — no interior obstacles this level.
        break;
    }
    _carveGuaranteedDoorway();
  }

  void _blockIfOpen(int r, int c) {
    if (r < 0 || r >= rows || c < 0 || c >= cols) return;
    if (cells[r][c] == CellState.open) cells[r][c] = CellState.blocked;
  }

  void _forceOpen(int r, int c) {
    if (r < 0 || r >= rows || c < 0 || c >= cols) return;
    if (cells[r][c] == CellState.blocked) cells[r][c] = CellState.open;
  }

  /// Forces a short, few-cells-wide corridor open just below the border
  /// spawn point, deep enough to punch through any shape's narrowest
  /// point near the edge. This is the actual fix for shapes (like the
  /// diamond) whose boundary only mathematically touches the border at
  /// a single non-integer point — on a real grid that rounds to a fully
  /// sealed row with no way in at all.
  void _carveGuaranteedDoorway() {
    final rTop = _borderThickness;
    final doorCol = borderSpawnPoint.col;
    const corridorHalfWidth = 1; // 3 cells wide
    const corridorDepth = 4; // rows deep, enough to clear any vertex seal
    for (int r = rTop; r < rTop + corridorDepth && r < rows; r++) {
      for (int c = doorCol - corridorHalfWidth;
          c <= doorCol + corridorHalfWidth;
          c++) {
        _forceOpen(r, c);
      }
    }
  }

  void _carveCrossShape(Random rng) {
    final rTop = _borderThickness, rBottom = rows - _borderThickness - 1;
    final cLeft = _borderThickness, cRight = cols - _borderThickness - 1;
    // Randomize how thick the corner blocks are (25%-38%) so the arm
    // width of the cross varies level to level.
    final fraction = 0.25 + rng.nextDouble() * 0.13;
    final blockH = ((rBottom - rTop + 1) * fraction).round();
    final blockW = ((cRight - cLeft + 1) * fraction).round();
    for (int r = rTop; r <= rBottom; r++) {
      final inTopBand = r < rTop + blockH;
      final inBottomBand = r > rBottom - blockH;
      if (!inTopBand && !inBottomBand) continue;
      for (int c = cLeft; c <= cRight; c++) {
        final inLeftBand = c < cLeft + blockW;
        final inRightBand = c > cRight - blockW;
        if (inLeftBand || inRightBand) _blockIfOpen(r, c);
      }
    }
  }

  void _carveDiamondShape(Random rng) {
    final rTop = _borderThickness, rBottom = rows - _borderThickness - 1;
    final cLeft = _borderThickness, cRight = cols - _borderThickness - 1;
    // Nudge the center off true-middle and vary the slack threshold so
    // the diamond isn't always perfectly centered/identical in size.
    final centerR = (rTop + rBottom) / 2 + (rng.nextDouble() - 0.5) * 4;
    final centerC = (cLeft + cRight) / 2 + (rng.nextDouble() - 0.5) * 4;
    final halfH = (rBottom - rTop) / 2;
    final halfW = (cRight - cLeft) / 2;
    final slack = 1.1 + rng.nextDouble() * 0.15;
    for (int r = rTop; r <= rBottom; r++) {
      for (int c = cLeft; c <= cRight; c++) {
        final dr = (r - centerR).abs() / (halfH == 0 ? 1 : halfH);
        final dc = (c - centerC).abs() / (halfW == 0 ? 1 : halfW);
        if (dr + dc > slack) _blockIfOpen(r, c);
      }
    }
  }

  void _carveHourglassShape(Random rng) {
    final rTop = _borderThickness, rBottom = rows - _borderThickness - 1;
    final cLeft = _borderThickness, cRight = cols - _borderThickness - 1;
    final horizontal = rng.nextBool(); // alternate waist orientation
    final primaryStart = horizontal ? cLeft : rTop;
    final primaryEnd = horizontal ? cRight : rBottom;
    final crossHalfExtent =
        ((horizontal ? rBottom - rTop : cRight - cLeft) / 2).toDouble();
    final crossCenter = (horizontal ? (rTop + rBottom) : (cLeft + cRight)) / 2;
    final pinch = 0.75 + rng.nextDouble() * 0.2;
    final length = primaryEnd - primaryStart;
    if (length <= 0) return;
    for (int p = primaryStart; p <= primaryEnd; p++) {
      final normalized = (p - primaryStart) / length; // 0..1
      final distFromCenter = (normalized - 0.5).abs() * 2; // 1 edges, 0 middle
      final rawMargin = crossHalfExtent * (1 - distFromCenter) * pinch;
      final margin = min(rawMargin, crossHalfExtent - 2).round();
      for (int off = 0; off < margin; off++) {
        final low = (crossCenter - crossHalfExtent + off).round();
        final high = (crossCenter + crossHalfExtent - off).round();
        if (horizontal) {
          _blockIfOpen(low, p);
          _blockIfOpen(high, p);
        } else {
          _blockIfOpen(p, low);
          _blockIfOpen(p, high);
        }
      }
    }
  }

  /// A field of small square "pillar" obstacles in a loose grid, spacing
  /// and size randomized per level — reads like a checkerboard of cover.
  void _carvePillarField(Random rng) {
    final rTop = _borderThickness, rBottom = rows - _borderThickness - 1;
    final cLeft = _borderThickness, cRight = cols - _borderThickness - 1;
    final spacing = 4 + rng.nextInt(3); // 4-6 cells between pillars
    final pillarSize = 1 + rng.nextInt(2); // 1x1 or 2x2
    for (int r = rTop + 2; r <= rBottom - 2; r += spacing) {
      for (int c = cLeft + 2; c <= cRight - 2; c += spacing) {
        final jitterR = rng.nextInt(2);
        final jitterC = rng.nextInt(2);
        for (int dr = 0; dr < pillarSize; dr++) {
          for (int dc = 0; dc < pillarSize; dc++) {
            _blockIfOpen(r + jitterR + dr, c + jitterC + dc);
          }
        }
      }
    }
  }

  /// Alternating brick-like bands jutting in from left and right, forcing
  /// a snaking path through the level. Band count/thickness randomized.
  void _carveZigzagCorridor(Random rng) {
    final rTop = _borderThickness, rBottom = rows - _borderThickness - 1;
    final cLeft = _borderThickness, cRight = cols - _borderThickness - 1;
    final bandHeight = 3 + rng.nextInt(2); // 3-4 rows per band
    final reachFraction = 0.55 + rng.nextDouble() * 0.2; // how far bands jut in
    final width = cRight - cLeft;
    bool fromLeft = rng.nextBool();
    for (int r = rTop; r <= rBottom; r += bandHeight) {
      final reach = (width * reachFraction).round();
      for (int i = 0; i < bandHeight && r + i <= rBottom; i++) {
        for (int off = 0; off < reach; off++) {
          final c = fromLeft ? cLeft + off : cRight - off;
          _blockIfOpen(r + i, c);
        }
      }
      fromLeft = !fromLeft;
    }
  }

  /// Concentric square rings — an onion-like maze. Every ring gets a
  /// guaranteed vertical breach at the same column (so there's always a
  /// straight shaft connecting the border all the way to the center,
  /// regardless of how many rings deep the level goes) plus one extra
  /// randomized gap per ring for visual variety and alternate routes.
  void _carveRingGaps(Random rng) {
    final rTop = _borderThickness, rBottom = rows - _borderThickness - 1;
    final cLeft = _borderThickness, cRight = cols - _borderThickness - 1;
    final ringSpacing = 3 + rng.nextInt(2); // 3-4 cells apart
    final gapWidth = 3 + rng.nextInt(3);
    final breachCol = borderSpawnPoint.col;
    int inset = ringSpacing;

    while (rTop + inset < rBottom - inset && cLeft + inset < cRight - inset) {
      final top = rTop + inset, bottom = rBottom - inset;
      final left = cLeft + inset, right = cRight - inset;

      for (int c = left; c <= right; c++) {
        _blockIfOpen(top, c);
        _blockIfOpen(bottom, c);
      }
      for (int r = top; r <= bottom; r++) {
        _blockIfOpen(r, left);
        _blockIfOpen(r, right);
      }

      // Guaranteed shaft through every ring at the same column, so the
      // whole nested structure is always solvable end to end — not just
      // the outermost layer.
      for (int c = breachCol - 1; c <= breachCol + 1; c++) {
        _forceOpen(top, c);
      }

      // A second, randomized gap elsewhere on this ring for variety.
      final span = (right - left).clamp(1, 1 << 30);
      final gapAt = rng.nextInt(span);
      switch (rng.nextInt(4)) {
        case 0:
          for (int i = 0; i < gapWidth; i++) {
            _forceOpen(top, (left + gapAt + i).clamp(left, right));
          }
          break;
        case 1:
          for (int i = 0; i < gapWidth; i++) {
            _forceOpen((top + gapAt + i).clamp(top, bottom), right);
          }
          break;
        case 2:
          for (int i = 0; i < gapWidth; i++) {
            _forceOpen(bottom, (left + gapAt + i).clamp(left, right));
          }
          break;
        default:
          for (int i = 0; i < gapWidth; i++) {
            _forceOpen((top + gapAt + i).clamp(top, bottom), left);
          }
      }

      inset += ringSpacing;
    }
  }

  /// Scattered rounded-rectangle "rubble" obstacles at random positions —
  /// count scales gently with level so later levels feel a bit busier.
  void _carveScatteredBlobs(Random rng, int level) {
    final rTop = _borderThickness, rBottom = rows - _borderThickness - 1;
    final cLeft = _borderThickness, cRight = cols - _borderThickness - 1;
    final blobCount = 5 + (level ~/ 3).clamp(0, 10) + rng.nextInt(3);
    for (int i = 0; i < blobCount; i++) {
      final w = 2 + rng.nextInt(3);
      final h = 2 + rng.nextInt(3);
      final r = rTop + rng.nextInt((rBottom - rTop - h).clamp(1, 1 << 30));
      final c = cLeft + rng.nextInt((cRight - cLeft - w).clamp(1, 1 << 30));
      for (int dr = 0; dr < h; dr++) {
        for (int dc = 0; dc < w; dc++) {
          _blockIfOpen(r + dr, c + dc);
        }
      }
    }
  }

  bool inBounds(GridPos p) =>
      p.row >= 0 && p.row < rows && p.col >= 0 && p.col < cols;

  CellState stateAt(GridPos p) => cells[p.row][p.col];

  bool isSolid(GridPos p) => !inBounds(p) || stateAt(p) == CellState.blocked;

  /// A safe starting point on the claimed top border, centered horizontally.
  /// Spawning here (instead of just inside the open field) means the player
  /// begins standing on already-claimed ground, matching how the original
  /// mechanic reads: you venture OUT from safety, you don't start exposed.
  GridPos get borderSpawnPoint => GridPos(_borderThickness - 1, cols ~/ 2);

  bool get isDrawingTrail => _activeTrail.isNotEmpty;

  List<GridPos> get activeTrail => List.unmodifiable(_activeTrail);

  /// Converts a world (pixel) position into a grid cell.
  GridPos worldToGrid(Offset world) {
    final r = (world.dy / cellSize).floor().clamp(0, rows - 1);
    final c = (world.dx / cellSize).floor().clamp(0, cols - 1);
    return GridPos(r, c);
  }

  Offset gridToWorldCenter(GridPos p) => Offset(
        p.col * cellSize + cellSize / 2,
        p.row * cellSize + cellSize / 2,
      );

  /// Returns a random open (non-blocked, non-claimed) cell — used to place
  /// enemies without spawning them inside a wall or on safe ground.
  GridPos randomOpenCell(Random rng) {
    while (true) {
      final r = _borderThickness + rng.nextInt(rows - _borderThickness * 2);
      final c = _borderThickness + rng.nextInt(cols - _borderThickness * 2);
      if (cells[r][c] == CellState.open) return GridPos(r, c);
    }
  }

  /// Call every time the player's occupied cell changes.
  /// Returns true if a loop was just closed & territory captured.
  bool onPlayerEnterCell(GridPos p, List<GridPos> enemyCells) {
    final state = stateAt(p);

    if (state == CellState.claimed) {
      if (_activeTrail.isNotEmpty) {
        // Loop closed: bake the trail into claimed territory then flood fill.
        for (final t in _activeTrail) {
          cells[t.row][t.col] = CellState.claimed;
        }
        _activeTrail.clear();
        _floodFillCapture(enemyCells);
        return true;
      }
      return false;
    }

    // Open cell: extend (or start) the trail.
    if (state == CellState.open) {
      cells[p.row][p.col] = CellState.trail;
      _activeTrail.add(p);
    }
    return false;
  }

  /// Called when the player is caught mid-trail (hit by enemy or edge case).
  void clearTrail() {
    for (final t in _activeTrail) {
      cells[t.row][t.col] = CellState.open;
    }
    _activeTrail.clear();
  }

  void _floodFillCapture(List<GridPos> enemyCells) {
    final enemySet = enemyCells.toSet();
    final visited = List.generate(rows, (_) => List.filled(cols, false));

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (cells[r][c] != CellState.open || visited[r][c]) continue;

        // BFS this connected component of open cells.
        final region = <GridPos>[];
        final queue = Queue<GridPos>();
        queue.add(GridPos(r, c));
        visited[r][c] = true;
        bool containsEnemy = false;

        while (queue.isNotEmpty) {
          final cur = queue.removeFirst();
          region.add(cur);
          if (enemySet.contains(cur)) containsEnemy = true;

          for (final n in _neighbors(cur)) {
            if (!inBounds(n)) continue;
            if (visited[n.row][n.col]) continue;
            if (cells[n.row][n.col] != CellState.open) continue;
            visited[n.row][n.col] = true;
            queue.add(n);
          }
        }

        if (!containsEnemy) {
          for (final p in region) {
            cells[p.row][p.col] = CellState.claimed;
          }
        }
      }
    }
  }

  Iterable<GridPos> _neighbors(GridPos p) sync* {
    yield GridPos(p.row - 1, p.col);
    yield GridPos(p.row + 1, p.col);
    yield GridPos(p.row, p.col - 1);
    yield GridPos(p.row, p.col + 1);
  }

  /// Percentage (0-100) of the *claimable* grid that is claimed. Blocked
  /// (wall) cells are excluded from both sides of this ratio since they
  /// were never part of the capturable playfield.
  double get claimedPercent {
    int claimed = 0;
    int claimable = 0;
    for (final row in cells) {
      for (final c in row) {
        if (c == CellState.blocked) continue;
        claimable++;
        if (c == CellState.claimed) claimed++;
      }
    }
    if (claimable == 0) return 0;
    return claimed / claimable * 100;
  }
}

// Minimal Queue so we don't need dart:collection import clutter elsewhere.
class Queue<T> {
  final List<T> _items = [];

  void add(T item) => _items.add(item);

  T removeFirst() => _items.removeAt(0);

  bool get isNotEmpty => _items.isNotEmpty;
}
