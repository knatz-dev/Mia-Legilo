import 'package:flutter/material.dart';

/// One-tap bookmark control. It does not open a dialog.
class BookmarkButton extends StatelessWidget {
  const BookmarkButton({
    super.key,
    required this.active,
    required this.onPressed,
    this.enabled = true,
  });

  final bool active;
  final VoidCallback? onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: active ? 'Remove bookmark' : 'Add bookmark',
      onPressed: enabled ? onPressed : null,
      icon: Icon(active ? Icons.bookmark : Icons.bookmark_border),
    );
  }
}
