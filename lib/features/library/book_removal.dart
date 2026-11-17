import 'package:material_ui/material_ui.dart';

import '../../core/design/fields.dart';
import '../../core/design/tokens.dart';
import '../../core/design/widgets.dart';
import '../../domain/book.dart';
import '../../library/library_service.dart';

/// Returns true only after the explicitly selected local operation succeeds.
Future<bool> confirmBookRemoval(
  BuildContext context,
  LibraryService library,
  Book book, {
  required bool downloadOnly,
}) async {
  final choice = await showDialog<String>(
    context: context,
    builder: (ctx) => SketchDialog(
      title: downloadOnly ? 'Remove download?' : 'Remove local import?',
      seedKey: downloadOnly ? 'remove-download' : 'remove-import',
      content: Text(
        downloadOnly
            ? 'Delete only the app-managed EPUB copy of "${book.title}". Keep '
                  'its library entry, status, progress and bookmarks.'
            : 'Hide "${book.title}" from your library. Keep the EPUB file; use '
                  'Remove download separately to delete it. No server book is '
                  'deleted.',
        style: const TextStyle(fontSize: 14, height: 1.5, color: kInk),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        if (downloadOnly)
          SketchButton(
            label: 'Remove download',
            danger: true,
            onPressed: () => Navigator.pop(ctx, 'download'),
          )
        else ...<Widget>[
          SketchButton(
            label: 'Keep reading data',
            onPressed: () => Navigator.pop(ctx, 'retain'),
          ),
          SketchButton(
            label: 'Delete reading data',
            danger: true,
            onPressed: () => Navigator.pop(ctx, 'purge'),
          ),
        ],
      ],
    ),
  );
  if (choice == null) return false;
  try {
    if (choice == 'download') {
      await library.removeDownload(book.id);
    } else {
      await library.removeLocalImport(
        book.id,
        deleteReadingData: choice == 'purge',
      );
    }
    return true;
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Removal failed: $error')));
    }
    return false;
  }
}
