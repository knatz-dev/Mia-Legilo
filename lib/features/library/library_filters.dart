import 'package:material_ui/material_ui.dart';

import '../../domain/book.dart';
import '../../library/library_query.dart';

class LibraryFilters extends StatefulWidget {
  const LibraryFilters({super.key, required this.query, required this.books});
  final LibraryQuery query;
  final List<Book> books;

  @override
  State<LibraryFilters> createState() => _LibraryFiltersState();
}

class _LibraryFiltersState extends State<LibraryFilters> {
  late LibraryQuery _query = widget.query;
  String _dimension = 'Authors';
  String _search = '';

  Set<String> get _selected => switch (_dimension) {
    'Authors' => _query.authors,
    'Series' => _query.series,
    _ => _query.shelfIds,
  };

  @override
  Widget build(BuildContext context) {
    final values = <String>{
      ..._selected,
      for (final book in widget.books)
        ...switch (_dimension) {
          'Authors' => authorValues(book),
          'Series' => {(book.series ?? '').trim()},
          _ => book.shelfIds.map((s) => s.value).toSet(),
        },
    }.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    String label(String value) => value.isNotEmpty
        ? value
        : (_dimension == 'Authors' ? 'Unknown author' : 'Unassigned');
    final visible = values
        .where((v) => label(v).toLowerCase().contains(_search.toLowerCase()))
        .toList();
    return AlertDialog(
      title: const Text('Filter library'),
      content: SizedBox(
        width: 440,
        height: 360,
        child: Column(
          children: [
            DropdownButton<String>(
              value: _dimension,
              isExpanded: true,
              items: [
                'Authors',
                'Series',
                'Shelves',
              ].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
              onChanged: (value) {
                if (value != null) setState(() => _dimension = value);
              },
            ),
            TextField(
              decoration: const InputDecoration(labelText: 'Find filter value'),
              onChanged: (value) => setState(() => _search = value),
            ),
            const Text(
              'Match any selected value; combine dimensions with AND.',
            ),
            Expanded(
              child: visible.isEmpty
                  ? const Center(
                      child: Text('No values in the cached library.'),
                    )
                  : ListView.builder(
                      itemCount: visible.length,
                      itemBuilder: (context, index) {
                        final value = visible[index];
                        return CheckboxListTile(
                          title: Text(label(value)),
                          value: _selected.contains(value),
                          onChanged: (checked) => setState(() {
                            final next = {..._selected};
                            if (checked == true) {
                              next.add(value);
                            } else {
                              next.remove(value);
                            }
                            _query = switch (_dimension) {
                              'Authors' => _query.copyWith(authors: next),
                              'Series' => _query.copyWith(series: next),
                              _ => _query.copyWith(shelfIds: next),
                            };
                          }),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => setState(
            () =>
                _query = _query.copyWith(authors: {}, series: {}, shelfIds: {}),
          ),
          child: const Text('Clear selections'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _query),
          child: const Text('Apply'),
        ),
      ],
    );
  }
}
