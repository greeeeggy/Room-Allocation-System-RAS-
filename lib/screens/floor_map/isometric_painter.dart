import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../models/room_model.dart';
import '../../core/constants.dart';

/// Renders a single floor of rooms in isometric (2.5D) projection.
///
/// Each room is a tile with three visible faces: top (status colour),
/// left (darker shade), right (darkest shade).  The caller provides the
/// list of [rooms] for ONE floor and a [selectedRoomId] for highlighting.
///
/// Tap detection is handled externally via [onRoomTap]; this painter
/// exposes [hitTest] so the parent widget can map a tap position to a
/// room ID.
class IsometricFloorPainter extends CustomPainter {
  final List<RoomModel> rooms;
  final String? selectedRoomId;

  // Tile dimensions
  static const double tileW = 64.0;
  static const double tileH = 32.0;
  static const double tileDepth = 10.0;

  IsometricFloorPainter({
    required this.rooms,
    this.selectedRoomId,
  });

  // ── Colour helpers ────────────────────────────────────────────────────

  Color _topColor(RoomModel room) {
    if (room.roomId == selectedRoomId) return Colors.blue.shade300;
    switch (room.status) {
      case RoomStatus.occupied:
        return AppColors.occupied;
      case RoomStatus.soon:
        return AppColors.soon;
      case RoomStatus.available:
        return AppColors.available;
      case RoomStatus.noClass:
        return Colors.blueGrey.shade300;
    }
  }

  // ── Iso projection ────────────────────────────────────────────────────

  /// Converts grid (col, row) to screen (x, y) with the origin at the
  /// top-centre of the canvas.
  Offset _isoOrigin(int col, int row, Size size) {
    final sx = (col - row) * tileW / 2 + size.width / 2;
    final sy = (col + row) * tileH / 2 + 20.0;
    return Offset(sx, sy);
  }

  // ── Paint ─────────────────────────────────────────────────────────────

  @override
  void paint(Canvas canvas, Size size) {
    // Sort by (col + row) descending so closer tiles paint on top.
    final sorted = List<RoomModel>.from(rooms)
      ..sort((a, b) => (a.col + a.row).compareTo(b.col + b.row));

    for (final room in sorted) {
      _drawTile(canvas, size, room);
    }
  }

  void _drawTile(Canvas canvas, Size size, RoomModel room) {
    final o = _isoOrigin(room.col, room.row, size);
    final top = _topColor(room);
    final left = top.withOpacity(0.65);
    final right = top.withOpacity(0.42);
    final selected = room.roomId == selectedRoomId;

    // ── Top face ─────────────────────────────────────────────────────
    final topPath = Path()
      ..moveTo(o.dx, o.dy)
      ..lineTo(o.dx + tileW / 2, o.dy + tileH / 2)
      ..lineTo(o.dx, o.dy + tileH)
      ..lineTo(o.dx - tileW / 2, o.dy + tileH / 2)
      ..close();
    canvas.drawPath(topPath, Paint()..color = top);

    // ── Left face ────────────────────────────────────────────────────
    final leftPath = Path()
      ..moveTo(o.dx - tileW / 2, o.dy + tileH / 2)
      ..lineTo(o.dx, o.dy + tileH)
      ..lineTo(o.dx, o.dy + tileH + tileDepth)
      ..lineTo(o.dx - tileW / 2, o.dy + tileH / 2 + tileDepth)
      ..close();
    canvas.drawPath(leftPath, Paint()..color = left);

    // ── Right face ───────────────────────────────────────────────────
    final rightPath = Path()
      ..moveTo(o.dx, o.dy + tileH)
      ..lineTo(o.dx + tileW / 2, o.dy + tileH / 2)
      ..lineTo(o.dx + tileW / 2, o.dy + tileH / 2 + tileDepth)
      ..lineTo(o.dx, o.dy + tileH + tileDepth)
      ..close();
    canvas.drawPath(rightPath, Paint()..color = right);

    // ── Outline ──────────────────────────────────────────────────────
    final outlinePaint = Paint()
      ..color = selected ? Colors.blue.shade700 : Colors.black26
      ..style = PaintingStyle.stroke
      ..strokeWidth = selected ? 1.5 : 0.8;
    canvas.drawPath(topPath, outlinePaint);

    // ── Room label ───────────────────────────────────────────────────
    final tp = TextPainter(
      text: TextSpan(
        text: room.roomNumber,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: Colors.white.withOpacity(0.9),
          shadows: const [
            Shadow(offset: Offset(0, 1), blurRadius: 2, color: Colors.black38)
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(o.dx - tp.width / 2, o.dy + tileH / 2 - tp.height / 2),
    );
  }

  @override
  bool shouldRepaint(IsometricFloorPainter old) =>
      old.rooms != rooms || old.selectedRoomId != selectedRoomId;

  // ── Room search by position ──────────────────────────────────────────

  /// Returns the roomId whose top-face diamond contains [tapPosition],
  /// or null if no tile was hit.  Tests in reverse paint order (front tiles
  /// first).
  String? getRoomAtPosition(Offset tapPosition, Size size) {
    final sorted = List<RoomModel>.from(rooms)
      ..sort((a, b) => (b.col + b.row).compareTo(a.col + a.row));

    for (final room in sorted) {
      final o = _isoOrigin(room.col, room.row, size);
      final topPath = Path()
        ..moveTo(o.dx, o.dy)
        ..lineTo(o.dx + tileW / 2, o.dy + tileH / 2)
        ..lineTo(o.dx, o.dy + tileH)
        ..lineTo(o.dx - tileW / 2, o.dy + tileH / 2)
        ..close();
      if (topPath.contains(tapPosition)) return room.roomId;
    }
    return null;
  }
}
