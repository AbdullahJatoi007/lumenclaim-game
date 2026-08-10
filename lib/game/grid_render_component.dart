import 'dart:ui';
import 'package:flame/components.dart';
import 'grid_system.dart';

/// Paints the playfield each frame: dark open space, gradient-filled
/// claimed territory, and a glowing trail behind the player.
class GridRenderComponent extends Component {
  final GridSystem grid;

  GridRenderComponent({required this.grid});

  static const Color openColor = Color(0xFF0B1220);
  static const Color claimedColorA = Color(0xFF1A3A5C);
  static const Color claimedColorB = Color(0xFF12294A);
  static const Color trailColor = Color(0xFF4DE3FF);
  static const Color blockedColor = Color(0xFF241033);
  static const Color blockedEdge = Color(0x552EE6D6);

  final Paint _claimedPaint = Paint()..color = claimedColorA;
  final Paint _trailPaint = Paint()..color = trailColor.withOpacity(0.85);
  final Paint _blockedPaint = Paint()..color = blockedColor;
  final Paint _blockedEdgePaint = Paint()
    ..color = blockedEdge
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1;

  @override
  void render(Canvas canvas) {
    final bgPaint = Paint()..color = openColor;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, grid.cols * grid.cellSize, grid.rows * grid.cellSize),
      bgPaint,
    );

    for (int r = 0; r < grid.rows; r++) {
      for (int c = 0; c < grid.cols; c++) {
        final state = grid.cells[r][c];
        if (state == CellState.open) continue;
        final rect = Rect.fromLTWH(
          c * grid.cellSize,
          r * grid.cellSize,
          grid.cellSize + 0.5,
          grid.cellSize + 0.5,
        );
        if (state == CellState.claimed) {
          canvas.drawRect(rect, _claimedPaint);
        } else if (state == CellState.trail) {
          canvas.drawRect(rect, _trailPaint);
        } else if (state == CellState.blocked) {
          canvas.drawRect(rect, _blockedPaint);
          canvas.drawRect(rect, _blockedEdgePaint);
        }
      }
    }
  }
}
