import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'tokens.dart';

/// A text field with a hand-drawn ink outline that stays in place while
/// typing. The stroke is a fixed seeded path, so focus and fill never redraw
/// it at a different wobble.
class SketchTextField extends StatefulWidget {
  const SketchTextField({
    super.key,
    required this.label,
    this.controller,
    this.hintText,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.autofocus = false,
    this.enabled = true,
    this.maxLines = 1,
    this.onChanged,
    this.seedKey,
  });

  final String label;
  final TextEditingController? controller;
  final String? hintText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final bool autofocus;
  final bool enabled;
  final int? maxLines;
  final ValueChanged<String>? onChanged;
  final String? seedKey;

  @override
  State<SketchTextField> createState() => _SketchTextFieldState();
}

class _SketchTextFieldState extends State<SketchTextField> {
  late final FocusNode _focusNode;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: widget.label);
    _focusNode.addListener(_onFocus);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocus);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocus() {
    if (mounted) setState(() => _focused = _focusNode.hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    final Color outline = _focused ? kAccent : kBorderInk;
    final double stroke = _focused ? kStrokeFocus : kStrokeHairline;
    final String key = widget.seedKey ?? 'field-${widget.label}';

    // The visible field is the Material TextField; the sketch stroke is
    // painted behind it so the wobble is never covered by the fill.
    return Semantics(
      label: widget.label,
      textField: true,
      child: CustomPaint(
        foregroundPainter: SketchOutlinePainter(
          color: outline,
          strokeWidth: stroke,
          seed: sketchSeedFor(key),
          radius: 3,
          roughness: kRoughness,
        ),
        child: Container(
          color: widget.enabled ? kPaperSurface : kPaper,
          padding: const EdgeInsets.symmetric(horizontal: kSpace3),
          child: Row(
            children: <Widget>[
              if (widget.prefixIcon != null) ...<Widget>[
                Icon(
                  widget.prefixIcon,
                  size: 20,
                  color: _focused ? kAccent : kInkMuted,
                ),
                const SizedBox(width: kSpace2),
              ],
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focusNode,
                  enabled: widget.enabled,
                  obscureText: widget.obscureText,
                  keyboardType: widget.keyboardType,
                  autofocus: widget.autofocus,
                  maxLines: widget.maxLines,
                  onChanged: widget.onChanged,
                  style: const TextStyle(
                    fontSize: 15,
                    color: kInk,
                    height: 1.5,
                  ),
                  cursorColor: kAccent,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: kSpace3,
                    ),
                    labelText: widget.label,
                    hintText: widget.hintText,
                    hintStyle: const TextStyle(color: kInkDisabled),
                    labelStyle: const TextStyle(
                      color: kInkMuted,
                      fontSize: 14.5,
                    ),
                    floatingLabelStyle: const TextStyle(
                      color: kAccent,
                      fontSize: 13.5,
                    ),
                  ),
                ),
              ),
              if (widget.suffixIcon != null) ...<Widget>[
                const SizedBox(width: kSpace2),
                IconTheme(
                  data: IconThemeData(color: _focused ? kAccent : kInkMuted),
                  child: widget.suffixIcon!,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A modal dialog with a sketch outline, a clear title, and a labelled
/// action row. Brief confirmations and quick edits use this.
class SketchDialog extends StatelessWidget {
  const SketchDialog({
    super.key,
    required this.title,
    required this.actions,
    this.content,
    this.seedKey,
  });

  final String title;
  final Widget? content;
  final List<Widget> actions;
  final String? seedKey;

  @override
  Widget build(BuildContext context) {
    final String key = seedKey ?? 'dialog-$title';
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(
        horizontal: kSpace4,
        vertical: kSpace5,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: CustomPaint(
          foregroundPainter: SketchOutlinePainter(
            color: kBorderInk,
            strokeWidth: kStrokeHairline,
            seed: sketchSeedFor(key),
            radius: 3,
            roughness: kRoughness,
          ),
          child: Padding(
            padding: const EdgeInsets.all(kSpace5),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: kInk,
                    ),
                  ),
                ),
                if (content != null) ...<Widget>[
                  const SizedBox(height: kSpace3),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 420),
                    child: SingleChildScrollView(child: content),
                  ),
                ],
                const SizedBox(height: kSpace5),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Wrap(
                    spacing: kSpace2,
                    runSpacing: kSpace2,
                    alignment: WrapAlignment.end,
                    children: actions,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A bottom sheet with a hand-drawn top edge and a grab handle drawn as a
/// short uneven stroke.
class SketchSheet extends StatelessWidget {
  const SketchSheet({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.seedKey,
  });

  final String title;
  final Widget child;
  final List<Widget>? actions;
  final String? seedKey;

  @override
  Widget build(BuildContext context) {
    final String key = seedKey ?? 'sheet-$title';
    return Padding(
      padding: const EdgeInsets.all(kSpace2),
      child: CustomPaint(
        foregroundPainter: SketchOutlinePainter(
          color: kBorderInk,
          strokeWidth: kStrokeHairline,
          seed: sketchSeedFor(key),
          radius: 3,
          roughness: kRoughness,
        ),
        child: Container(
          color: kPaperSurface,
          padding: const EdgeInsets.fromLTRB(
            kSpace5,
            kSpace2,
            kSpace5,
            kSpace5,
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Center(child: _SketchGrabHandle()),
                const SizedBox(height: kSpace3),
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: kInk,
                    ),
                  ),
                ),
                const SizedBox(height: kSpace4),
                Flexible(child: SingleChildScrollView(child: child)),
                if (actions != null && actions!.isNotEmpty) ...<Widget>[
                  const SizedBox(height: kSpace5),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: Wrap(
                      spacing: kSpace2,
                      runSpacing: kSpace2,
                      alignment: WrapAlignment.end,
                      children: actions!,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SketchGrabHandle extends StatelessWidget {
  const _SketchGrabHandle();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: const Size(44, 6), painter: _GrabHandlePainter());
  }
}

class _GrabHandlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..color = kInkMuted;
    final SketchRandom random = SketchRandom(sketchSeedFor('grab-handle'));
    final Path path = Path()..moveTo(0, size.height * 0.5);
    final int divisions = math.max(2, (size.width / 6).ceil());
    for (int i = 1; i <= divisions; i++) {
      path.lineTo(
        size.width * i / divisions,
        size.height * 0.5 + random.jitter(1.2),
      );
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_GrabHandlePainter oldDelegate) => false;
}

/// A compact toolbar used for search, sort and view toggles. It is a single
/// row on wide screens and wraps on narrow ones.
class SketchToolbar extends StatelessWidget {
  const SketchToolbar({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: kSpace2,
      runSpacing: kSpace2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: children,
    );
  }
}

/// A quiet notice that is not a card: ink text on paper with a hand-drawn
/// leading rule. Used for errors and confirmations inside a screen.
class SketchNotice extends StatelessWidget {
  const SketchNotice({
    super.key,
    required this.message,
    this.kind = SketchNoticeKind.info,
    this.seedKey,
  });

  final String message;
  final SketchNoticeKind kind;
  final String? seedKey;

  @override
  Widget build(BuildContext context) {
    final Color ink = switch (kind) {
      SketchNoticeKind.error => kAccent,
      SketchNoticeKind.info => kInkMuted,
    };
    final String key = seedKey ?? 'notice-$message';
    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          CustomPaint(
            size: const Size(3, 22),
            painter: _NoticeRulePainter(color: ink, seed: sketchSeedFor(key)),
          ),
          const SizedBox(width: kSpace3),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 14, height: 1.45, color: ink),
            ),
          ),
        ],
      ),
    );
  }
}

enum SketchNoticeKind { info, error }

class _NoticeRulePainter extends CustomPainter {
  _NoticeRulePainter({required this.color, required this.seed});

  final Color color;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..color = color;
    final SketchRandom random = SketchRandom(seed);
    final Path path = Path()..moveTo(size.width / 2, 0);
    final int divisions = 5;
    for (int i = 1; i <= divisions; i++) {
      path.lineTo(
        size.width / 2 + random.jitter(1.1),
        size.height * i / divisions,
      );
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_NoticeRulePainter oldDelegate) => false;
}

/// A compact status badge. Meaningful status only; decoration never uses it.
class SketchBadge extends StatelessWidget {
  const SketchBadge({
    super.key,
    required this.label,
    this.color = kInkMuted,
    this.seedKey,
  });

  final String label;
  final Color color;
  final String? seedKey;

  @override
  Widget build(BuildContext context) {
    final String key = seedKey ?? 'badge-$label';
    return CustomPaint(
      foregroundPainter: SketchOutlinePainter(
        color: color,
        strokeWidth: kStrokeHairline,
        seed: sketchSeedFor(key),
        radius: 2,
        roughness: kRoughness,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: kSpace2),
        alignment: Alignment.center,
        constraints: const BoxConstraints(minHeight: 26),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ),
    );
  }
}

/// A settings row: label plus value, with a sketch switch on the trailing
/// edge. Touch target stays 48dp.
class SketchSwitchRow extends StatelessWidget {
  const SketchSwitchRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      hint: subtitle,
      toggled: value,
      excludeSemantics: true,
      child: InkWell(
        onTap: () => onChanged(!value),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: kMinTarget + 8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: kSpace2),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: kInk,
                        ),
                      ),
                      if (subtitle != null) ...<Widget>[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: const TextStyle(
                            fontSize: 12.5,
                            height: 1.4,
                            color: kInkMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Switch(value: value, onChanged: onChanged),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A settings row that navigates to a dedicated page.
class SketchNavRow extends StatelessWidget {
  const SketchNavRow({
    super.key,
    required this.label,
    required this.onTap,
    this.value,
    this.icon,
  });

  final String label;
  final String? value;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      hint: value,
      button: true,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: kMinTarget + 8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: kSpace2),
            child: Row(
              children: <Widget>[
                if (icon != null) ...<Widget>[
                  Icon(icon, size: 20, color: kInkMuted),
                  const SizedBox(width: kSpace3),
                ],
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: kInk,
                    ),
                  ),
                ),
                if (value != null)
                  Padding(
                    padding: const EdgeInsets.only(right: kSpace2),
                    child: Text(
                      value!,
                      style: const TextStyle(fontSize: 13.5, color: kInkMuted),
                    ),
                  ),
                Icon(
                  Icons.chevron_right,
                  size: 22,
                  color: kInkMuted,
                  semanticLabel: label,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
