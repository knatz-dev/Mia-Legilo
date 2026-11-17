import 'package:material_ui/material_ui.dart';

import '../../core/design/fields.dart';
import '../../core/design/tokens.dart';
import '../../core/design/widgets.dart';
import '../../library/library_query.dart';
import 'connections_page.dart';
import 'settings_model.dart';
import 'settings_service.dart';

/// Settings overview. Each group is a directly linkable page.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.settings});

  final SettingsService settings;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SketchPage(
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: kSpace4,
            vertical: kSpace3,
          ),
          children: <Widget>[
            _SettingsGroup(
              heading: 'Personal',
              children: <Widget>[
                _GroupTile(
                  settings: widget.settings,
                  icon: Icons.cloud_outlined,
                  label: 'Connections',
                  description: 'CWNG servers and credentials',
                  route: _SettingsRoute.connections,
                ),
                _GroupTile(
                  settings: widget.settings,
                  icon: Icons.menu_book_outlined,
                  label: 'Library',
                  description:
                      'Defaults for sorting, filters and status shelves',
                  route: _SettingsRoute.library,
                ),
                _GroupTile(
                  settings: widget.settings,
                  icon: Icons.text_fields,
                  label: 'Reader',
                  description: 'Typography, themes and motion',
                  route: _SettingsRoute.reader,
                ),
              ],
            ),
            _SettingsGroup(
              heading: 'App',
              children: <Widget>[
                _GroupTile(
                  settings: widget.settings,
                  icon: Icons.palette_outlined,
                  label: 'Appearance',
                  description: 'Theme and sketch intensity',
                  route: _SettingsRoute.appearance,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum _SettingsRoute { connections, library, reader, appearance }

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.heading, required this.children});

  final String heading;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: kSpace5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(left: kSpace2, bottom: kSpace2),
            child: Semantics(
              container: true,
              header: true,
              child: SketchLabel(heading.toUpperCase()),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _GroupTile extends StatelessWidget {
  const _GroupTile({
    required this.settings,
    required this.icon,
    required this.label,
    required this.description,
    required this.route,
  });

  final SettingsService settings;
  final IconData icon;
  final String label;
  final String description;
  final _SettingsRoute route;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      hint: description,
      button: true,
      excludeSemantics: true,
      child: InkWell(
        onTap: () => _open(context),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: kMinTarget + 8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: kSpace2),
            child: Row(
              children: <Widget>[
                Icon(icon, size: 21, color: kInkMuted),
                const SizedBox(width: kSpace4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: kInk,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: const TextStyle(
                          fontSize: 12.5,
                          height: 1.4,
                          color: kInkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, size: 22, color: kInkMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context) {
    Widget page;
    switch (route) {
      case _SettingsRoute.connections:
        page = ConnectionSettingsPage(settings: settings);
      case _SettingsRoute.library:
        page = LibrarySettingsPage(settings: settings);
      case _SettingsRoute.reader:
        page = ReaderSettingsPage(settings: settings);
      case _SettingsRoute.appearance:
        page = AppearanceSettingsPage(settings: settings);
    }
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }
}

/// Wraps the settings tree so pages can read the service without threading it
/// through every constructor.
class SettingsHost extends StatelessWidget {
  const SettingsHost({super.key, required this.service, required this.child});

  final SettingsService service;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _SettingsScope(service: service, child: child);
  }
}

class _SettingsScope extends InheritedWidget {
  const _SettingsScope({required this.service, required super.child});

  final SettingsService service;

  @override
  bool updateShouldNotify(_SettingsScope oldWidget) =>
      oldWidget.service != service;
}

/// Appearance: app theme and sketch intensity.
class AppearanceSettingsPage extends StatefulWidget {
  const AppearanceSettingsPage({super.key, required this.settings});

  final SettingsService settings;

  @override
  State<AppearanceSettingsPage> createState() => _AppearanceSettingsPageState();
}

class _AppearanceSettingsPageState extends State<AppearanceSettingsPage> {
  AppearanceSettings? _settings;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final AppearanceSettings value = await widget.settings.appearance();
    if (mounted) setState(() => _settings = value);
  }

  Future<void> _save(AppearanceSettings next) async {
    setState(() => _settings = next);
    await widget.settings.saveAppearance(next);
  }

  @override
  Widget build(BuildContext context) {
    final AppearanceSettings? settings = _settings;
    return Scaffold(
      appBar: AppBar(title: const Text('Appearance')),
      body: settings == null
          ? const Center(child: CircularProgressIndicator())
          : SketchPage(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: kSpace4,
                  vertical: kSpace3,
                ),
                children: <Widget>[
                  const SketchSectionHeading('Theme'),
                  const SizedBox(height: kSpace2),
                  _ThemeModePicker(
                    value: settings.themeMode,
                    onChanged: (AppThemeMode mode) =>
                        _save(settings.copyWith(themeMode: mode)),
                  ),
                  const SizedBox(height: kSpace5),
                  const SketchSectionHeading('Sketch intensity'),
                  const SizedBox(height: kSpace2),
                  const Text(
                    'Quiet keeps outlines straight; Standard adds the uneven '
                    'stroke used across the app.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: kInkMuted,
                    ),
                  ),
                  const SizedBox(height: kSpace3),
                  _IntensityPicker(
                    value: settings.sketchIntensity,
                    onChanged: (SketchIntensity value) =>
                        _save(settings.copyWith(sketchIntensity: value)),
                  ),
                ],
              ),
            ),
    );
  }
}

class _ThemeModePicker extends StatelessWidget {
  const _ThemeModePicker({required this.value, required this.onChanged});

  final AppThemeMode value;
  final ValueChanged<AppThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: kSpace2,
      children: <Widget>[
        for (final AppThemeMode mode in AppThemeMode.values)
          SketchFilterChip(
            label: switch (mode) {
              AppThemeMode.light => 'Light',
              AppThemeMode.dark => 'Dark',
              AppThemeMode.system => 'System',
            },
            selected: value == mode,
            onSelected: (_) => onChanged(mode),
            seedKey: 'theme-${mode.name}',
          ),
      ],
    );
  }
}

class _IntensityPicker extends StatelessWidget {
  const _IntensityPicker({required this.value, required this.onChanged});

  final SketchIntensity value;
  final ValueChanged<SketchIntensity> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: kSpace2,
      children: <Widget>[
        for (final SketchIntensity intensity in SketchIntensity.values)
          SketchFilterChip(
            label: switch (intensity) {
              SketchIntensity.quiet => 'Quiet',
              SketchIntensity.standard => 'Standard',
            },
            selected: value == intensity,
            onSelected: (_) => onChanged(intensity),
            seedKey: 'intensity-${intensity.name}',
          ),
      ],
    );
  }
}

/// Library settings: saved defaults for the temporary library controls.
class LibrarySettingsPage extends StatefulWidget {
  const LibrarySettingsPage({super.key, required this.settings});

  final SettingsService settings;

  @override
  State<LibrarySettingsPage> createState() => _LibrarySettingsPageState();
}

class _LibrarySettingsPageState extends State<LibrarySettingsPage> {
  LibraryDefaults? _defaults;
  LibraryBehaviour? _behaviour;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final LibraryDefaults defaults = await widget.settings.libraryDefaults();
    final LibraryBehaviour behaviour = await widget.settings.libraryBehaviour();
    if (!mounted) return;
    setState(() {
      _defaults = defaults;
      _behaviour = behaviour;
    });
  }

  Future<void> _saveDefaults(LibraryDefaults next) async {
    setState(() => _defaults = next);
    await widget.settings.saveLibraryDefaults(next);
  }

  Future<void> _saveBehaviour(LibraryBehaviour next) async {
    setState(() => _behaviour = next);
    await widget.settings.saveLibraryBehaviour(next);
  }

  @override
  Widget build(BuildContext context) {
    final LibraryDefaults? defaults = _defaults;
    final LibraryBehaviour? behaviour = _behaviour;
    return Scaffold(
      appBar: AppBar(title: const Text('Library')),
      body: defaults == null || behaviour == null
          ? const Center(child: CircularProgressIndicator())
          : SketchPage(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: kSpace4,
                  vertical: kSpace3,
                ),
                children: <Widget>[
                  const SketchSectionHeading('Library defaults'),
                  const SizedBox(height: kSpace2),
                  const Text(
                    'These apply when the library opens. Sorting, filtering, '
                    'grouping and search on the library screen stay temporary '
                    'until you change them.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: kInkMuted,
                    ),
                  ),
                  const SizedBox(height: kSpace4),
                  _PickerRow<LibraryViewMode>(
                    label: 'View',
                    value: defaults.viewMode,
                    values: LibraryViewMode.values,
                    labelOf: (LibraryViewMode v) =>
                        v == LibraryViewMode.grid ? 'Grid' : 'List',
                    onChanged: (LibraryViewMode v) =>
                        _saveDefaults(defaults.copyWith(viewMode: v)),
                  ),
                  _PickerRow<LibrarySortKey>(
                    label: 'Sort by',
                    value: defaults.sort,
                    values: LibrarySortKey.values,
                    labelOf: (LibrarySortKey v) => switch (v) {
                      LibrarySortKey.title => 'Title',
                      LibrarySortKey.author => 'Author',
                      LibrarySortKey.added => 'Added',
                      LibrarySortKey.lastRead => 'Last read',
                      LibrarySortKey.series => 'Series',
                      LibrarySortKey.progress => 'Progress',
                      LibrarySortKey.status => 'Status',
                    },
                    onChanged: (LibrarySortKey v) =>
                        _saveDefaults(defaults.copyWith(sort: v)),
                  ),
                  _PickerRow<LibrarySortDirection>(
                    label: 'Direction',
                    value: defaults.direction,
                    values: LibrarySortDirection.values,
                    labelOf: (LibrarySortDirection v) =>
                        v == LibrarySortDirection.ascending
                        ? 'Ascending'
                        : 'Descending',
                    onChanged: (LibrarySortDirection v) =>
                        _saveDefaults(defaults.copyWith(direction: v)),
                  ),
                  _PickerRow<LibraryGroupBy>(
                    label: 'Group by',
                    value: defaults.groupBy,
                    values: LibraryGroupBy.values,
                    labelOf: (LibraryGroupBy v) => switch (v) {
                      LibraryGroupBy.none => 'None',
                      LibraryGroupBy.author => 'Author',
                      LibraryGroupBy.series => 'Series',
                      LibraryGroupBy.status => 'Status',
                      LibraryGroupBy.source => 'Source',
                      LibraryGroupBy.availability => 'Availability',
                    },
                    onChanged: (LibraryGroupBy v) =>
                        _saveDefaults(defaults.copyWith(groupBy: v)),
                  ),
                  const SizedBox(height: kSpace5),
                  const SketchSectionHeading('Status shelves'),
                  const SizedBox(height: kSpace2),
                  SketchSwitchRow(
                    label: 'Automatically mark as Reading',
                    subtitle:
                        'On reading activity; manual statuses always take '
                        'precedence.',
                    value: behaviour.autoStartReading,
                    onChanged: (bool value) => _saveBehaviour(
                      behaviour.copyWith(autoStartReading: value),
                    ),
                  ),
                  const SizedBox(height: kSpace5),
                  SketchButton(
                    label: 'Restore library defaults',
                    icon: Icons.restart_alt,
                    expanded: true,
                    onPressed: () async {
                      await widget.settings.saveLibraryDefaults(
                        const LibraryDefaults(),
                      );
                      await widget.settings.saveLibraryBehaviour(
                        const LibraryBehaviour(),
                      );
                      await _load();
                    },
                  ),
                ],
              ),
            ),
    );
  }
}

class _PickerRow<T extends Enum> extends StatelessWidget {
  const _PickerRow({
    required this.label,
    required this.value,
    required this.values,
    required this.labelOf,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<T> values;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: kSpace4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SketchLabel(label),
          const SizedBox(height: kSpace2),
          Wrap(
            spacing: kSpace2,
            runSpacing: kSpace2,
            children: <Widget>[
              for (final T candidate in values)
                SketchFilterChip(
                  label: labelOf(candidate),
                  selected: candidate == value,
                  onSelected: (_) => onChanged(candidate),
                  seedKey: 'picker-$label-${candidate.name}',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Reader settings: typography, theme, layout and motion.
class ReaderSettingsPage extends StatefulWidget {
  const ReaderSettingsPage({super.key, required this.settings});

  final SettingsService settings;

  @override
  State<ReaderSettingsPage> createState() => _ReaderSettingsPageState();
}

class _ReaderSettingsPageState extends State<ReaderSettingsPage> {
  ReaderDefaults? _defaults;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final ReaderDefaults defaults = await widget.settings.readerDefaults();
    if (mounted) setState(() => _defaults = defaults);
  }

  Future<void> _save(ReaderDefaults next) async {
    setState(() => _defaults = next);
    await widget.settings.saveReaderDefaults(next);
  }

  @override
  Widget build(BuildContext context) {
    final ReaderDefaults? defaults = _defaults;
    return Scaffold(
      appBar: AppBar(title: const Text('Reader')),
      body: defaults == null
          ? const Center(child: CircularProgressIndicator())
          : SketchPage(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: kSpace4,
                  vertical: kSpace3,
                ),
                children: <Widget>[
                  const SketchSectionHeading('Device defaults'),
                  const SizedBox(height: kSpace2),
                  const Text(
                    'These are the defaults for every book. A book can keep '
                    'its own appearance while reading.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: kInkMuted,
                    ),
                  ),
                  const SizedBox(height: kSpace4),
                  _SliderRow(
                    label: 'Font size',
                    value: defaults.fontSize,
                    min: 12,
                    max: 28,
                    divisions: 16,
                    display: '${defaults.fontSize.round()} px',
                    onChanged: (double v) =>
                        _save(defaults.copyWith(fontSize: v)),
                  ),
                  _SliderRow(
                    label: 'Line height',
                    value: defaults.lineHeight,
                    min: 1.2,
                    max: 2.2,
                    divisions: 10,
                    display: defaults.lineHeight.toStringAsFixed(1),
                    onChanged: (double v) =>
                        _save(defaults.copyWith(lineHeight: v)),
                  ),
                  _SliderRow(
                    label: 'Margin',
                    value: defaults.margin,
                    min: 8,
                    max: 40,
                    divisions: 8,
                    display: '${defaults.margin.round()} px',
                    onChanged: (double v) =>
                        _save(defaults.copyWith(margin: v)),
                  ),
                  const SizedBox(height: kSpace4),
                  const SketchSectionHeading('Theme'),
                  const SizedBox(height: kSpace2),
                  Wrap(
                    spacing: kSpace2,
                    children: <Widget>[
                      for (final String theme in const <String>[
                        'light',
                        'dark',
                        'sepia',
                        'high-contrast',
                      ])
                        SketchFilterChip(
                          label: theme == 'high-contrast'
                              ? 'High contrast'
                              : theme[0].toUpperCase() + theme.substring(1),
                          selected: defaults.theme == theme,
                          onSelected: (_) =>
                              _save(defaults.copyWith(theme: theme)),
                          seedKey: 'reader-theme-$theme',
                        ),
                    ],
                  ),
                  const SizedBox(height: kSpace4),
                  const SketchSectionHeading('Layout'),
                  const SizedBox(height: kSpace2),
                  Wrap(
                    spacing: kSpace2,
                    children: <Widget>[
                      for (final String layout in const <String>[
                        'scrolled',
                        'paginated',
                      ])
                        SketchFilterChip(
                          label: layout == 'scrolled'
                              ? 'Continuous scroll'
                              : 'Paginated',
                          selected: defaults.layout == layout,
                          onSelected: (_) =>
                              _save(defaults.copyWith(layout: layout)),
                          seedKey: 'reader-layout-$layout',
                        ),
                    ],
                  ),
                  const SizedBox(height: kSpace4),
                  const SketchSectionHeading('Motion'),
                  const SizedBox(height: kSpace2),
                  SketchSwitchRow(
                    label: 'Reduced motion',
                    subtitle: 'Disable animations for e-ink or accessibility.',
                    value: defaults.reducedMotion,
                    onChanged: (bool value) =>
                        _save(defaults.copyWith(reducedMotion: value)),
                  ),
                ],
              ),
            ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.display,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String display;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: kSpace4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              SketchLabel(label),
              Text(
                display,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: kAccent,
                ),
              ),
            ],
          ),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            label: display,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
