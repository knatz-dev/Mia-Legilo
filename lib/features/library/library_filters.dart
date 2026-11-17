import 'package:material_ui/material_ui.dart';

import '../../core/design/fields.dart';
import '../../core/design/tokens.dart';
import '../../core/design/widgets.dart';
import '../../domain/book.dart';
import '../../library/library_query.dart';

/// Advanced filter values (authors, series, shelves) in a sketch dialog.
///
/// The frequently used filters stay on the library screen; this is the
/// expanded editor for the values that need a list.
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

    return SketchDialog(
      title: 'Filter library',
      seedKey: 'library-filters',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Match any selected value; combine dimensions with AND.',
            style: TextStyle(fontSize: 13, height: 1.45, color: kInkMuted),
          ),
          const SizedBox(height: kSpace4),
          const SketchLabel('DIMENSION'),
          const SizedBox(height: kSpace2),
          Wrap(
            spacing: kSpace2,
            children: <Widget>[
              for (final String dimension in const <String>[
                'Authors',
                'Series',
                'Shelves',
              ])
                SketchFilterChip(
                  label: dimension,
                  selected: _dimension == dimension,
                  onSelected: (_) => setState(() => _dimension = dimension),
                  seedKey: 'dimension-${dimension.toLowerCase()}',
                ),
            ],
          ),
          const SizedBox(height: kSpace4),
          SketchTextField(
            label: 'Find filter value',
            hintText: 'Type to narrow the list',
            onChanged: (String value) => setState(() => _search = value),
            seedKey: 'filter-value-search',
          ),
          const SizedBox(height: kSpace3),
          if (visible.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: kSpace4),
              child: Text(
                'No values in the cached library.',
                style: TextStyle(fontSize: 13.5, color: kInkMuted),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: visible.length,
                itemBuilder: (BuildContext context, int index) {
                  final String value = visible[index];
                  return CheckboxListTile(
                    value: _selected.contains(value),
                    onChanged: (bool? checked) => setState(() {
                      final Set<String> next = <String>{..._selected};
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
                    title: Text(
                      label(value),
                      style: const TextStyle(fontSize: 14.5, color: kInk),
                    ),
                    dense: true,
                  );
                },
              ),
            ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => setState(
            () => _query = _query.copyWith(
              authors: <String>{},
              series: <String>{},
              shelfIds: <String>{},
            ),
          ),
          child: const Text('Clear selections'),
        ),
        SketchButton(
          label: 'Apply',
          onPressed: () => Navigator.pop(context, _query),
        ),
      ],
    );
  }
}
