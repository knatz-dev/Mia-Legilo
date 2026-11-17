import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// Warm paper canvas for the whole app.
const Color kPaper = Color(0xFFFAF8F2);

/// Solid paper for cards and sheets. Kept opaque so content never shows
/// through; the sketch treatment carries the texture, not a blur.
const Color kPaperSurface = Color(0xFFFFFFFF);

/// High-contrast ink for body text and headings.
const Color kInk = Color(0xFF2D2A26);

/// Ink for secondary text. Contrast on [kPaper] is 6.6:1.
const Color kInkMuted = Color(0xFF615C55);

/// Ink for disabled text. Contrast on [kPaper] is 4.9:1.
const Color kInkDisabled = Color(0xFF8C857B);

/// The single muted accent. Contrast on [kPaper] is 4.9:1, so it is used
/// for text and strokes, never as a fill behind body text.
const Color kAccent = Color(0xFF8C4A2F);

/// Ink-tinted accent fill for selected chips and the primary button.
const Color kAccentFill = Color(0xFFEFE0D8);

/// Faint ink line for dividers and resting outlines.
const Color kBorderInk = Color(0xFF3A362F);

/// Muted line for list separators. Contrast on [kPaper] is 2.1:1, which is
/// enough for a decorative divider and never used for text.
const Color kBorderFaint = Color(0xFFD8D3C9);

/// Hairline for the sketch stroke of small controls.
const double kStrokeHairline = 1.15;

/// Stroke width for primary button outlines and selected marks.
const double kStrokeBold = 1.9;

/// Focus ring stroke width.
const double kStrokeFocus = 2.4;

/// Sketch roughness: how far a stroke may deviate from its ideal line.
/// [SketchIntensity.quiet] scales this to zero.
const double kRoughness = 0.9;

/// Spacing scale, in logical pixels. All layout gaps come from here.
const double kSpace1 = 4;
const double kSpace2 = 8;
const double kSpace3 = 12;
const double kSpace4 = 16;
const double kSpace5 = 24;
const double kSpace6 = 32;
const double kSpace7 = 48;

/// Minimum interactive bound (SPEC ACC-001).
const double kMinTarget = 48;

/// Base body size. Never scaled below 14 logical pixels.
const double kBodySize = 16;

/// Motion durations. Short and deterministic; the reader disables them.
const Duration kMotionFast = Duration(milliseconds: 140);
const Duration kMotionBase = Duration(milliseconds: 220);

/// How strongly the hand-drawn treatment is applied.
enum SketchIntensity {
  quiet(0.0),
  standard(kRoughness);

  const SketchIntensity(this.roughness);

  /// Roughness used by sketch painters at this intensity.
  final double roughness;
}

/// Deterministic PRNG. The hand-drawn strokes must not change between
/// rebuilds, so every sketch painter seeds from a fixed integer.
class SketchRandom {
  SketchRandom([this.seed = 1234567]);

  final int seed;
  int _state = 0;

  double next() {
    _state = (_state * 1103515245 + seed * 12345 + 12345) & 0x7fffffff;
    return (_state % 100000) / 100000;
  }

  /// Symmetric jitter in [-amount, amount].
  double jitter(double amount) => (next() * 2 - 1) * amount;
}

/// Derives a stable seed from an arbitrary key so a given control always
/// draws the same hand.
int sketchSeedFor(String key) {
  var h = 2166136261;
  for (final int code in key.codeUnits) {
    h = (h ^ code) * 16777619 & 0x7fffffff;
  }
  return h == 0 ? 1 : h;
}

/// One hand-drawn pass over a straight segment. The jitter follows a sine
/// envelope so endpoints stay put and the middle of the stroke wanders.
Path _roughSegment({
  required Offset from,
  required Offset to,
  required SketchRandom random,
  required double roughness,
  required double strokeWidth,
}) {
  final Path path = Path()..moveTo(from.dx, from.dy);
  final double length = (to - from).distance;
  final int divisions = math.max(2, (length / 9).ceil());
  final double perpX = -(to.dy - from.dy);
  final double perpY = to.dx - from.dx;
  final double perpLength = math
      .sqrt(perpX * perpX + perpY * perpY)
      .clamp(1, double.infinity);
  final double nx = perpX / perpLength;
  final double ny = perpY / perpLength;

  for (int i = 1; i <= divisions; i++) {
    final double t = i / divisions;
    // Scale the jitter by the pen width so a hairline and a bold outline
    // wobble by the same proportion.
    final double envelope = math.sin(t * math.pi);
    final double offset = random.jitter(roughness * strokeWidth * envelope);
    path.lineTo(
      from.dx + (to.dx - from.dx) * t + nx * offset,
      from.dy + (to.dy - from.dy) * t + ny * offset,
    );
  }
  return path;
}

/// A hand-drawn rounded rectangle. [passes] overlays a second stroke on the
/// same path so the outline reads as one confident line.
Path roughRectPath({
  required Rect rect,
  required double roughness,
  required int seed,
  double radius = 2,
  double strokeWidth = kStrokeHairline,
  int passes = 2,
}) {
  final SketchRandom random = SketchRandom(seed);
  // A degenerate box (zero or negative extent) has no outline to draw.
  if (rect.width <= 0 || rect.height <= 0) {
    return Path();
  }
  final double r = radius.clamp(0.0, math.min(rect.width, rect.height) / 2);
  final List<Offset> corners = <Offset>[
    Offset(rect.left + r, rect.top),
    Offset(rect.right - r, rect.top),
    Offset(rect.right, rect.top + r),
    Offset(rect.right, rect.bottom - r),
    Offset(rect.right - r, rect.bottom),
    Offset(rect.left + r, rect.bottom),
    Offset(rect.left, rect.bottom - r),
    Offset(rect.left, rect.top + r),
  ];
  final Path path = Path()..moveTo(corners.first.dx, corners.first.dy);
  for (int i = 0; i < corners.length; i++) {
    final Offset a = corners[i];
    final Offset b = corners[(i + 1) % corners.length];
    final Path segment = _roughSegment(
      from: a,
      to: b,
      random: random,
      roughness: roughness,
      strokeWidth: strokeWidth,
    );
    path.addPath(segment, Offset.zero);
  }
  path.close();
  for (int pass = 1; pass < passes; pass++) {
    final Path second = Path();
    final List<Offset> altCorners = corners
        .map(
          (Offset c) => Offset(
            c.dx + random.jitter(roughness * strokeWidth * 0.5),
            c.dy + random.jitter(roughness * strokeWidth * 0.5),
          ),
        )
        .toList();
    second.moveTo(altCorners.first.dx, altCorners.first.dy);
    for (int i = 0; i < altCorners.length; i++) {
      final Offset a = altCorners[i];
      final Offset b = altCorners[(i + 1) % altCorners.length];
      second.addPath(
        _roughSegment(
          from: a,
          to: b,
          random: random,
          roughness: roughness * 0.45,
          strokeWidth: strokeWidth,
        ),
        Offset.zero,
      );
    }
    second.close();
    // Both passes share one stroke, so the weight does not double.
    path.addPath(second, Offset.zero);
  }
  return path;
}

/// Painter for a single sketch outline.
class SketchOutlinePainter extends CustomPainter {
  SketchOutlinePainter({
    required this.color,
    required this.strokeWidth,
    required this.seed,
    this.roughness = kRoughness,
    this.radius = 2,
    this.passes = 2,
  });

  final Color color;
  final double strokeWidth;
  final int seed;
  final double roughness;
  final double radius;
  final int passes;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    final Rect rect = Offset.zero & size;
    final Path path = roughRectPath(
      rect: rect.deflate(strokeWidth / 2),
      roughness: roughness,
      seed: seed,
      radius: radius,
      strokeWidth: strokeWidth,
      passes: passes,
    );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(SketchOutlinePainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.seed != seed ||
      oldDelegate.roughness != roughness;
}

/// A card boundary that is only drawn when a group needs one.
class SketchCard extends StatelessWidget {
  const SketchCard({
    super.key,
    required this.child,
    this.seedKey,
    this.padding = const EdgeInsets.all(kSpace4),
    this.color = kPaperSurface,
    this.strokeColor = kBorderInk,
    this.strokeWidth = kStrokeHairline,
    this.roughness = kRoughness,
    this.radius = 3,
    this.passes = 2,
  });

  final Widget child;
  final String? seedKey;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color strokeColor;
  final double strokeWidth;
  final double roughness;
  final double radius;
  final int passes;

  @override
  Widget build(BuildContext context) {
    final String key = seedKey ?? identityHashCode(this).toString();
    return CustomPaint(
      foregroundPainter: SketchOutlinePainter(
        color: strokeColor,
        strokeWidth: strokeWidth,
        seed: sketchSeedFor(key),
        roughness: roughness,
        radius: radius,
        passes: passes,
      ),
      child: ColoredBox(
        color: color,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
