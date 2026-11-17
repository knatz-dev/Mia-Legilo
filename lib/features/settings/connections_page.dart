import 'package:material_ui/material_ui.dart';

import '../../core/design/fields.dart';
import '../../core/design/tokens.dart';
import '../../core/design/widgets.dart';
import '../../integrations/cwng/credential_store.dart';
import 'settings_model.dart';
import 'settings_service.dart';

/// Connections: add, edit and remove CWNG server profiles.
///
/// Credentials are entered once and written to platform secure storage keyed
/// by profile id; this page never displays a password (SPEC CON-002), and the
/// non-secret [ConnectionProfile] JSON never carries one.
class ConnectionSettingsPage extends StatefulWidget {
  const ConnectionSettingsPage({
    super.key,
    required this.settings,
    this.credentials,
  });

  final SettingsService settings;
  final CwngCredentialStore? credentials;

  @override
  State<ConnectionSettingsPage> createState() => _ConnectionSettingsPageState();
}

class _ConnectionSettingsPageState extends State<ConnectionSettingsPage> {
  CwngCredentialStore get _credentials =>
      widget.credentials ?? CwngCredentialStore();

  List<ConnectionProfile> _profiles = <ConnectionProfile>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final List<ConnectionProfile> profiles = await widget.settings
        .connections();
    if (!mounted) return;
    setState(() {
      _profiles = profiles;
      _loading = false;
    });
  }

  Future<void> _persist() => widget.settings.saveConnections(_profiles);

  Future<void> _add() async {
    final _ConnectionDraft? draft = await showDialog<_ConnectionDraft>(
      context: context,
      builder: (_) => const _ConnectionEditDialog(),
    );
    if (draft == null) return;
    if (draft.password.isNotEmpty) {
      await _credentials.write(
        draft.profile.id,
        draft.profile.username,
        draft.password,
      );
    }
    setState(() {
      _profiles = <ConnectionProfile>[
        ..._profiles.where((ConnectionProfile p) => p.id != draft.profile.id),
        draft.profile,
      ];
    });
    await _persist();
  }

  Future<void> _edit(ConnectionProfile profile) async {
    final _ConnectionDraft? draft = await showDialog<_ConnectionDraft>(
      context: context,
      builder: (_) => _ConnectionEditDialog(existing: profile),
    );
    if (draft == null) return;
    if (draft.password.isNotEmpty) {
      await _credentials.write(
        draft.profile.id,
        draft.profile.username,
        draft.password,
      );
    }
    setState(() {
      _profiles = <ConnectionProfile>[
        for (final ConnectionProfile p in _profiles)
          if (p.id == draft.profile.id) draft.profile else p,
      ];
    });
    await _persist();
  }

  Future<void> _remove(ConnectionProfile profile) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => SketchDialog(
        title: 'Remove connection?',
        seedKey: 'remove-connection',
        content: Text(
          'Remove the profile for "${profile.label ?? profile.serverUrl}". '
          'Downloaded books stay in your library.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          SketchButton(
            label: 'Remove',
            danger: true,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _credentials.delete(profile.id);
    setState(
      () => _profiles = <ConnectionProfile>[
        ..._profiles.where((ConnectionProfile p) => p.id != profile.id),
      ],
    );
    await _persist();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connections')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: const Text('Add connection'),
        backgroundColor: kAccent,
        foregroundColor: kPaper,
      ),
      body: SketchPage(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _profiles.isEmpty
            ? const _EmptyConnections()
            : ListView(
                padding: const EdgeInsets.fromLTRB(
                  kSpace4,
                  kSpace3,
                  kSpace4,
                  kSpace7 + kSpace5,
                ),
                children: <Widget>[
                  const SketchSectionHeading('Saved connections'),
                  const SizedBox(height: kSpace2),
                  const Text(
                    'Credentials are stored in secure storage and never shown '
                    'here.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: kInkMuted,
                    ),
                  ),
                  const SizedBox(height: kSpace4),
                  for (final ConnectionProfile profile in _profiles)
                    _ConnectionTile(
                      profile: profile,
                      onEdit: () => _edit(profile),
                      onRemove: () => _remove(profile),
                    ),
                ],
              ),
      ),
    );
  }
}

class _EmptyConnections extends StatelessWidget {
  const _EmptyConnections();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(kSpace5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.cloud_off_outlined, size: 40, color: kInkMuted),
            const SizedBox(height: kSpace3),
            const Text(
              'No connections yet.\nAdd a CWNG server to browse and download.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, height: 1.5, color: kInkMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionTile extends StatelessWidget {
  const _ConnectionTile({
    required this.profile,
    required this.onEdit,
    required this.onRemove,
  });

  final ConnectionProfile profile;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: kSpace3),
      child: SketchSurface(
        seedKey: 'connection-${profile.id}',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    profile.label ?? profile.username,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: kInk,
                    ),
                  ),
                ),
                SketchIconButton(
                  icon: Icons.edit_outlined,
                  tooltip: 'Edit connection',
                  onPressed: onEdit,
                ),
                SketchIconButton(
                  icon: Icons.delete_outline,
                  tooltip: 'Remove connection',
                  onPressed: onRemove,
                ),
              ],
            ),
            const SizedBox(height: kSpace1),
            Text(
              profile.serverUrl,
              style: const TextStyle(fontSize: 13, color: kInkMuted),
            ),
            if (profile.lastConnectedAt != null) ...<Widget>[
              const SizedBox(height: kSpace1),
              SketchBadge(
                label:
                    'Connected ${profile.lastConnectedAt!.toLocal().toString().split(' ').first}',
                seedKey: 'connected-${profile.id}',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ConnectionDraft {
  const _ConnectionDraft({required this.profile, required this.password});

  final ConnectionProfile profile;

  /// Empty means "keep the stored secret"; non-empty replaces it.
  final String password;
}

class _ConnectionEditDialog extends StatefulWidget {
  const _ConnectionEditDialog({this.existing});

  final ConnectionProfile? existing;

  @override
  State<_ConnectionEditDialog> createState() => _ConnectionEditDialogState();
}

class _ConnectionEditDialogState extends State<_ConnectionEditDialog> {
  late final TextEditingController _label = TextEditingController(
    text: widget.existing?.label ?? '',
  );
  late final TextEditingController _url = TextEditingController(
    text: widget.existing?.serverUrl ?? '',
  );
  late final TextEditingController _user = TextEditingController(
    text: widget.existing?.username ?? '',
  );
  late final TextEditingController _pass = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _label.dispose();
    _url.dispose();
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  void _save() {
    final String url = _url.text.trim();
    final String user = _user.text.trim();
    final String password = _pass.text;
    final Uri? uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      setState(() => _error = 'Enter a valid server URL, including https://');
      return;
    }
    if (user.isEmpty) {
      setState(() => _error = 'Enter a username.');
      return;
    }
    if (widget.existing == null && password.isEmpty) {
      setState(() => _error = 'Enter a password or app password.');
      return;
    }
    Navigator.of(context).pop(
      _ConnectionDraft(
        profile: ConnectionProfile(
          id:
              widget.existing?.id ??
              'cwng-${uri.host}-${DateTime.now().microsecondsSinceEpoch}',
          serverUrl: url,
          username: user,
          label: _label.text.trim().isEmpty ? uri.host : _label.text.trim(),
          lastConnectedAt: widget.existing?.lastConnectedAt,
        ),
        password: password,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SketchDialog(
      title: widget.existing == null ? 'Add connection' : 'Edit connection',
      seedKey: 'connection-dialog',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SketchTextField(
            label: 'Label',
            controller: _label,
            hintText: 'Home library',
            seedKey: 'conn-label',
          ),
          const SizedBox(height: kSpace3),
          SketchTextField(
            label: 'Server URL',
            controller: _url,
            hintText: 'https://library.example.org',
            keyboardType: TextInputType.url,
            seedKey: 'conn-url',
          ),
          const SizedBox(height: kSpace3),
          SketchTextField(
            label: 'Username',
            controller: _user,
            seedKey: 'conn-user',
          ),
          const SizedBox(height: kSpace3),
          SketchTextField(
            label: widget.existing == null
                ? 'Password or app password'
                : 'Password (leave blank to keep)',
            controller: _pass,
            obscureText: true,
            seedKey: 'conn-pass',
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: kSpace3),
            SketchNotice(message: _error!, kind: SketchNoticeKind.error),
          ],
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        SketchButton(label: 'Save', onPressed: _save),
      ],
    );
  }
}
