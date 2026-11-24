import 'dart:async';
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

  /// Name label with an optional "+N" badge, and the top-view car (as on
  /// Live Track) under it, turned to [course]. The car's centre sits on the
  /// location. [tint] null keeps the original green car (Running).
  Future<MarkerIcon> group({
    required String plate,
    required int extra,
    required bool selected,
    required Color? tint,
    required double course,
    required double carSize,
  }) {
    final key =
        'g|$plate|$extra|$selected|${tint?.toARGB32()}|${course.round()}|$carSize';
    return _icons.putIfAbsent(key, () async {
      final car = _TopCarBox(await _topCar(tint), course, carSize);
      final label = _LabelPainter(
        plate,
        selected: selected,
        extra: extra,
        small: false,
        maxWidth: 156,
      );
      const margin = 4.0; // room for the label shadow
      final w = math.max(label.width, car.boxW) + margin * 2;
      final h = margin + label.height + 4 + car.boxH + margin;
      final centre = Offset(w / 2, margin + label.height + 4 + car.boxH / 2);
      return _render(Size(w, h), centre, (c) {
        label.paint(c, Offset((w - label.width) / 2, margin));
        car.paint(c, centre);
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

  /// Top-down car tinted as on Live Track ([tint] null = original green),
  /// turned to [course] degrees; centre anchored.
  Future<MarkerIcon> topCar({
    required Color? tint,
    required double course,
    required double size,
  }) {
    final key = 't|${tint?.toARGB32()}|${course.round()}|$size';
    return _icons.putIfAbsent(key, () async {
      final car = _TopCarBox(await _topCar(tint), course, size);
      final centre = Offset(car.boxW / 2, car.boxH / 2);
      return _render(Size(car.boxW, car.boxH), centre, (c) {
        car.paint(c, centre);
      });
    });
  }

  final Map<int?, Future<ui.Image>> _topCars = {};

  /// The top-view car in [tint], recoloured the same way as on Live Track:
  /// only the green body changes, keeping its shading; windows, lights and
  /// outlines stay as they are.
  Future<ui.Image> _topCar(Color? tint) =>
      _topCars.putIfAbsent(tint?.toARGB32(), () async {
        final src = await _image(topCarAsset);
        if (tint == null) return src;
        final data =
            await src.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
        final px = data!.buffer.asUint8List();
        final tr = (tint.r * 255).round();
        final tg = (tint.g * 255).round();
        final tb = (tint.b * 255).round();
        for (var i = 0; i < px.length; i += 4) {
          if (px[i + 3] == 0) continue;
          final r = px[i];
          final g = px[i + 1];
          final b = px[i + 2];
          if (g > r + 40 && g > b + 25) {
            // The body green is ~190 in G: scale the colour by the shade.
            final shade = g / 190.0;
            px[i] = (tr * shade).round().clamp(0, 255);
            px[i + 1] = (tg * shade).round().clamp(0, 255);
            px[i + 2] = (tb * shade).round().clamp(0, 255);
          }
        }
        final done = Completer<ui.Image>();
        ui.decodeImageFromPixels(
          px,
          src.width,
          src.height,
          ui.PixelFormat.rgba8888,
          done.complete,
        );
        return done.future;
      });

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

/// The top-view car cropped to the car itself, as big as a [size] square of
/// the artwork, turned to [course] degrees. The artwork is a square with the
/// car in its middle; its empty sides would make neighbouring cars' tap
/// areas overlap, and Google would open the wrong car.
class _TopCarBox {
  _TopCarBox(this.img, double course, double size)
      : a = course * math.pi / 180 {
    final iw = img.width.toDouble();
    final ih = img.height.toDouble();
    src = Rect.fromLTRB(iw * 0.264, ih * 0.034, iw * 0.732, ih * 0.942);
    final s = size / math.max(iw, ih);
    w = src.width * s;
    h = src.height * s;
    boxW = (w * math.cos(a)).abs() + (h * math.sin(a)).abs();
    boxH = (w * math.sin(a)).abs() + (h * math.cos(a)).abs();
  }

  final ui.Image img;
  final double a;
  late final Rect src;
  late final double w;
  late final double h;

  /// Picture just big enough for the car at this angle.
  late final double boxW;
  late final double boxH;

  void paint(Canvas c, Offset centre) {
    c.save();
    c.translate(centre.dx, centre.dy);
    c.rotate(a);
    c.drawImageRect(
      img,
      src,
      Rect.fromCenter(center: Offset.zero, width: w, height: h),
      Paint()..filterQuality = FilterQuality.high,
    );
    c.restore();
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
