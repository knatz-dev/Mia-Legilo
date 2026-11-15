import 'package:material_ui/material_ui.dart';

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
    builder: (ctx) => AlertDialog(
      title: Text(downloadOnly ? 'Remove download?' : 'Remove local import?'),
      content: Text(
        downloadOnly
            ? 'Delete only the app-managed EPUB copy of "${book.title}". Keep its library entry, status, progress and bookmarks.'
            : 'Hide "${book.title}" from your library. Keep the EPUB file; use Remove download separately to delete it. Choose whether to retain reading data for a later re-import. No server book is deleted.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        if (downloadOnly)
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'download'),
            child: const Text('Remove download'),
          )
        else ...[
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'retain'),
            child: const Text('Keep reading data'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'purge'),
            child: const Text('Delete reading data'),
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
