import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// A marker picture for the Location map, with where its "point" is.
class MarkerIcon {
  const MarkerIcon(this.descriptor, this.size, this.anchorPoint);

  final BitmapDescriptor descriptor;

  /// Logical size of the picture.
  final Size size;

  /// Point of the picture (logical px) that sits on the map location.
  final Offset anchorPoint;

  /// [anchorPoint] as Google's 0..1 anchor, moved by [shift] logical px
  /// (positive x = picture drawn further right).
  Offset anchor([Offset shift = Offset.zero]) => Offset(
        (anchorPoint.dx - shift.dx) / size.width,
        (anchorPoint.dy - shift.dy) / size.height,
      );
}

/// Draws the Location markers (Google markers are pictures, not widgets),
/// looking the same as the Flutter versions they replace. Pictures are
/// cached, so moving the map only redraws what changed.
class LocationMarkerIcons {
  LocationMarkerIcons(this.devicePixelRatio);

  final double devicePixelRatio;

  static const String topCarAsset = 'lib/Asset/Icons/Track Vehicle Top.png';

  final Map<String, Future<ui.Image>> _images = {};
  final Map<String, Future<MarkerIcon>> _icons = {};

  Future<ui.Image> _image(String asset) => _images.putIfAbsent(asset, () async {
        final data = await rootBundle.load(asset);
        final codec =
            await ui.instantiateImageCodec(data.buffer.asUint8List());
        return (await codec.getNextFrame()).image;
      });

  /// Name label with an optional "+N" badge, and the side-view car under it.
  /// The car's centre sits on the location.
  Future<MarkerIcon> group({
    required String plate,
    required int extra,
    required bool selected,
    required String carAsset,
    required double carSize,
  }) {
    final key = 'g|$plate|$extra|$selected|$carAsset|$carSize';
    return _icons.putIfAbsent(key, () async {
      final car = await _image(carAsset);
      final label = _LabelPainter(
        plate,
        selected: selected,
        extra: extra,
        small: false,
        maxWidth: 156,
      );
      const margin = 4.0; // room for the label shadow
      final w = math.max(label.width, carSize) + margin * 2;
      final h = margin + label.height + 4 + carSize + margin;
      final carTop = margin + label.height + 4;
      return _render(Size(w, h), Offset(w / 2, carTop + carSize / 2), (c) {
        label.paint(c, Offset((w - label.width) / 2, margin));
        _drawContain(c, car, Rect.fromLTWH((w - carSize) / 2, carTop, carSize, carSize));
      });
    });
  }

  /// Small name label alone; its bottom centre is the anchor.
  Future<MarkerIcon> label({required String plate, required bool selected}) {
    final key = 'l|$plate|$selected';
    return _icons.putIfAbsent(key, () async {
      final label = _LabelPainter(
        plate,
        selected: selected,
        extra: 0,
        small: true,
        maxWidth: 160,
      );
      const margin = 3.0;
      final w = label.width + margin * 2;
      final h = label.height + margin * 2;
      return _render(Size(w, h), Offset(w / 2, margin + label.height), (c) {
        label.paint(c, const Offset(margin, margin));
      });
    });
  }

  /// Top-down car in [color], turned to [course] degrees; centre anchored.
  Future<MarkerIcon> topCar({
    required Color color,
    required double course,
    required double size,
  }) {
    final key = 't|${color.toARGB32()}|${course.round()}|$size';
    return _icons.putIfAbsent(key, () async {
      final img = await _image(topCarAsset);
      // Grey out the green artwork, then paint it in the status colour; the
      // 1.65 keeps the body as bright as the colour itself.
      const k = 1.65;
      final r = color.r * k;
      final g = color.g * k;
      final b = color.b * k;
      final paint = Paint()
        ..filterQuality = FilterQuality.high
        ..colorFilter = ColorFilter.matrix([
          0.2126 * r, 0.7152 * r, 0.0722 * r, 0, 0, //
          0.2126 * g, 0.7152 * g, 0.0722 * g, 0, 0, //
          0.2126 * b, 0.7152 * b, 0.0722 * b, 0, 0, //
          0, 0, 0, 1, 0,
        ]);
      return _render(Size(size, size), Offset(size / 2, size / 2), (c) {
        c.translate(size / 2, size / 2);
        c.rotate(course * math.pi / 180);
        c.translate(-size / 2, -size / 2);
        _drawContain(c, img, Rect.fromLTWH(0, 0, size, size), paint);
      });
    });
  }

  void _drawContain(Canvas c, ui.Image img, Rect box, [Paint? paint]) {
    final iw = img.width.toDouble();
    final ih = img.height.toDouble();
    final s = math.min(box.width / iw, box.height / ih);
    final dst = Rect.fromCenter(center: box.center, width: iw * s, height: ih * s);
    c.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, iw, ih),
      dst,
      paint ?? (Paint()..filterQuality = FilterQuality.high),
    );
  }

  Future<MarkerIcon> _render(
    Size size,
    Offset anchorPoint,
    void Function(Canvas c) draw,
  ) async {
    final dpr = devicePixelRatio;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(dpr);
    draw(canvas);
    final image = await recorder.endRecording().toImage(
          (size.width * dpr).ceil(),
          (size.height * dpr).ceil(),
        );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final descriptor = BitmapDescriptor.bytes(
      bytes!.buffer.asUint8List(),
      width: size.width,
      height: size.height,
    );
    return MarkerIcon(descriptor, size, anchorPoint);
  }
}

/// Black (or blue when selected) rounded name pill, as on the old markers.
class _LabelPainter {
  _LabelPainter(
    String plate, {
    required this.selected,
    required this.extra,
    required this.small,
    required double maxWidth,
  }) {
    final hPad = small ? 8.0 : 12.0;
    final badgeW = extra > 0 ? _badge.width + 12 + 6 : 0.0;
    _text = TextPainter(
      text: TextSpan(
        text: plate.isEmpty ? '—' : plate,
        style: TextStyle(
          color: Colors.white,
          fontSize: small ? 10 : 12,
          fontWeight: FontWeight.bold,
          height: 1,
        ),
      ),
      maxLines: 1,
      ellipsis: '…',
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: math.max(20, maxWidth - hPad * 2 - badgeW));
    width = _text.width + hPad * 2 + badgeW;
    height = small ? 20 : 26;
  }

  final bool selected;
  final int extra;
  final bool small;
  late final TextPainter _text;
  late final double width;
  late final double height;

  late final TextPainter _badge = TextPainter(
    text: TextSpan(
      text: '+$extra',
      style: TextStyle(
        color: selected ? const Color(0xFF009FE3) : Colors.black,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        height: 1,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  void paint(Canvas c, Offset at) {
    final radius = small ? 6.0 : height / 2;
    final rect = RRect.fromRectAndRadius(
      at & Size(width, height),
      Radius.circular(radius),
    );
    c.drawRRect(
      rect.shift(const Offset(0, 2)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    c.drawRRect(
      rect,
      Paint()..color = selected ? const Color(0xFF009FE3) : Colors.black,
    );
    final hPad = small ? 8.0 : 12.0;
    _text.paint(
      c,
      Offset(at.dx + hPad, at.dy + (height - _text.height) / 2),
    );
    if (extra > 0) {
      final bw = _badge.width + 12;
      final bh = _badge.height + 6;
      final bx = at.dx + hPad + _text.width + 6;
      final by = at.dy + (height - bh) / 2;
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(bx, by, bw, bh),
          const Radius.circular(10),
        ),
        Paint()..color = Colors.white,
      );
      _badge.paint(c, Offset(bx + 6, by + 3));
    }
  }
}
