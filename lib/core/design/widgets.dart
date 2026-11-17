import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'tokens.dart';

/// Fills the sketch stroke without a blur or drop shadow: the card sits on
/// the paper, the outline carries the hand-drawn feel.
class SketchSurface extends StatelessWidget {
  const SketchSurface({
    super.key,
    required this.child,
    this.seedKey,
    this.color = kPaperSurface,
    this.padding = const EdgeInsets.all(kSpace4),
    this.strokeColor = kBorderInk,
    this.strokeWidth = kStrokeHairline,
    this.roughness = kRoughness,
    this.radius = 3,
  });

  final Widget child;
  final String? seedKey;
  final Color color;
  final EdgeInsetsGeometry padding;
  final Color strokeColor;
  final double strokeWidth;
  final double roughness;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final String key = seedKey ?? 'surface-${identityHashCode(this)}';
    return CustomPaint(
      foregroundPainter: SketchOutlinePainter(
        color: strokeColor,
        strokeWidth: strokeWidth,
        seed: sketchSeedFor(key),
        roughness: roughness,
        radius: radius,
      ),
      child: ColoredBox(
        color: color,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// A label that reads as hand-annotated but stays in the body typeface.
class SketchLabel extends StatelessWidget {
  const SketchLabel(this.text, {super.key, this.color, this.fontSize});

  final String text;
  final Color? color;
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: fontSize ?? 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
        color: color ?? kInkMuted,
      ),
    );
  }
}

/// Constrains page content to a readable measure and centres it on wide
/// screens, so phone and tablet share one grid instead of a left-pinned
/// column with dead space on the right.
class SketchPage extends StatelessWidget {
  const SketchPage({super.key, required this.child, this.maxWidth = 720});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// A section heading. Used where a visible boundary is not needed.
class SketchSectionHeading extends StatelessWidget {
  const SketchSectionHeading(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
          color: kInk,
        ),
      ),
    );
  }
}

/// Primary action button: accent fill, wobbly ink outline, steady stroke.
class SketchButton extends StatelessWidget {
  const SketchButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.filled = false,
    this.danger = false,
    this.seedKey,
    this.enabled = true,
    this.expanded = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool filled;
  final bool danger;
  final String? seedKey;
  final bool enabled;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final bool active = enabled && onPressed != null;
    final Color ink = danger ? kAccent : kInk;
    final Color fill = !active
        ? kPaper
        : danger
        ? kAccent
        : filled
        ? kAccent
        : kPaperSurface;
    final Color foreground = !active
        ? kInkDisabled
        : danger || filled
        ? kPaper
        : ink;
    final String key = seedKey ?? 'btn-$label';

    final Widget content = Row(
      mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        if (icon != null) ...<Widget>[
          Icon(icon, size: 18, color: foreground),
          const SizedBox(width: kSpace2),
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: foreground,
            ),
          ),
        ),
      ],
    );

    return Semantics(
      button: true,
      enabled: active,
      label: label,
      excludeSemantics: true,
      child: _SketchHitArea(
        seedKey: key,
        outlineColor: active ? ink : kInkDisabled,
        fillColor: fill,
        onTap: active ? onPressed : null,
        label: label,
        child: content,
      ),
    );
  }
}

/// Icon-only action with a 48dp target and an accessible name.
class SketchIconButton extends StatelessWidget {
  const SketchIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.selected = false,
    this.seedKey,
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool selected;
  final String? seedKey;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final bool active = onPressed != null;
    final Color foreground = color ?? (selected ? kAccent : kInk);
    return Semantics(
      label: tooltip,
      button: true,
      selected: selected,
      excludeSemantics: true,
      child: _SketchHitArea(
        seedKey: seedKey ?? 'icon-$tooltip',
        outlineColor: selected ? kAccent : kBorderInk,
        fillColor: selected ? kAccentFill : kPaperSurface,
        onTap: onPressed,
        label: tooltip,
        square: true,
        child: Icon(icon, size: 21, color: active ? foreground : kInkDisabled),
      ),
    );
  }
}

/// Wraps a child in a fixed 48dp square with a sketch outline and ink
/// response. The outline is redrawn only when selection changes, never on
/// tap, so the stroke stays in place during interaction.
class _SketchHitArea extends StatefulWidget {
  const _SketchHitArea({
    required this.seedKey,
    required this.outlineColor,
    required this.fillColor,
    required this.onTap,
    required this.label,
    required this.child,
    this.square = false,
  });

  final String seedKey;
  final Color outlineColor;
  final Color fillColor;
  final VoidCallback? onTap;
  final String label;
  final Widget child;
  final bool square;

  @override
  State<_SketchHitArea> createState() => _SketchHitAreaState();
}

class _SketchHitAreaState extends State<_SketchHitArea> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: widget.onTap != null,
      child: InkWell(
        onTap: widget.onTap,
        onTapDown: widget.onTap == null
            ? null
            : (_) => setState(() => _pressed = true),
        onTapUp: widget.onTap == null
            ? null
            : (_) => setState(() => _pressed = false),
        onTapCancel: widget.onTap == null
            ? null
            : () => setState(() => _pressed = false),
        borderRadius: BorderRadius.zero,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: widget.square ? kMinTarget : 96,
            minHeight: kMinTarget,
          ),
          child: CustomPaint(
            foregroundPainter: SketchOutlinePainter(
              color: widget.outlineColor,
              strokeWidth: kStrokeBold,
              seed: sketchSeedFor(widget.seedKey),
              radius: 3,
              roughness: kRoughness,
            ),
            child: ColoredBox(
              color: widget.fillColor,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: widget.square ? kSpace2 : kSpace3,
                ),
                child: Center(
                  widthFactor: 1,
                  heightFactor: 1,
                  child: Opacity(
                    // A pressed control darkens its fill only; the outline is
                    // untouched so the stroke never appears to move.
                    opacity: _pressed ? 0.86 : 1,
                    child: widget.child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A hand-drawn checkmark used for selected chips and filter values.
class SketchCheck extends StatelessWidget {
  const SketchCheck({super.key, this.size = 16, this.color = kInk});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _SketchCheckPainter(color: color),
    );
  }
}

class _SketchCheckPainter extends CustomPainter {
  _SketchCheckPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.1
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    final SketchRandom random = SketchRandom(sketchSeedFor('check'));
    final Path path = Path();
    final Offset start = Offset(size.width * 0.12, size.height * 0.55);
    final Offset mid = Offset(size.width * 0.4, size.height * 0.82);
    final Offset end = Offset(size.width * 0.9, size.height * 0.16);
    path.moveTo(start.dx + random.jitter(0.6), start.dy + random.jitter(0.6));
    path.quadraticBezierTo(
      mid.dx - size.width * 0.06,
      mid.dy + random.jitter(0.7),
      mid.dx + random.jitter(0.5),
      mid.dy + random.jitter(0.5),
    );
    path.quadraticBezierTo(
      end.dx - size.width * 0.12,
      end.dy + size.height * 0.12,
      end.dx + random.jitter(0.6),
      end.dy + random.jitter(0.6),
    );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SketchCheckPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// A selectable filter chip with an uneven underline and a sketch check.
class SketchFilterChip extends StatelessWidget {
  const SketchFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.seedKey,
    this.roughness = kRoughness,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;
  final String? seedKey;
  final double roughness;

  @override
  Widget build(BuildContext context) {
    final Color foreground = selected ? kAccent : kInk;
    final Color outline = selected ? kAccent : kBorderInk;
    final Color fill = selected ? kAccentFill : kPaperSurface;
    final String key = seedKey ?? 'chip-$label';
    return Semantics(
      label: label,
      button: true,
      selected: selected,
      excludeSemantics: true,
      child: _ChipTap(
        seedKey: key,
        outlineColor: outline,
        fillColor: fill,
        onTap: () => onSelected(!selected),
        roughness: roughness,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              width: 18,
              child: selected
                  ? const SketchCheck(size: 15, color: kAccent)
                  : const SizedBox.shrink(),
            ),
            const SizedBox(width: kSpace1),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChipTap extends StatefulWidget {
  const _ChipTap({
    required this.seedKey,
    required this.outlineColor,
    required this.fillColor,
    required this.onTap,
    required this.child,
    this.roughness = kRoughness,
  });

  final String seedKey;
  final Color outlineColor;
  final Color fillColor;
  final VoidCallback onTap;
  final Widget child;
  final double roughness;

  @override
  State<_ChipTap> createState() => _ChipTapState();
}

class _ChipTapState extends State<_ChipTap> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      borderRadius: BorderRadius.zero,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: kMinTarget),
        child: CustomPaint(
          foregroundPainter: SketchOutlinePainter(
            color: widget.outlineColor,
            strokeWidth: kStrokeHairline,
            seed: sketchSeedFor(widget.seedKey),
            radius: 3,
            roughness: widget.roughness,
          ),
          child: ColoredBox(
            color: widget.fillColor,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: kSpace3),
              child: Center(
                widthFactor: 1,
                heightFactor: 1,
                child: Opacity(
                  opacity: _pressed ? 0.86 : 1,
                  child: widget.child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A selected navigation underline with a faint, slightly uneven stroke.
class SketchNavUnderline extends StatelessWidget {
  const SketchNavUnderline({super.key, required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size(width, 5), painter: _UnderlinePainter());
  }
}

class _UnderlinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..color = kAccent;
    final SketchRandom random = SketchRandom(sketchSeedFor('nav-underline'));
    final Path path = Path()..moveTo(0, size.height * 0.6);
    final int divisions = math.max(2, (size.width / 7).ceil());
    for (int i = 1; i <= divisions; i++) {
      final double t = i / divisions;
      path.lineTo(size.width * t, size.height * 0.6 + random.jitter(1.1));
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_UnderlinePainter oldDelegate) => false;
}
