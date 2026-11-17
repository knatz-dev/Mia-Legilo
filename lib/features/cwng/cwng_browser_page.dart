import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

import '../../core/design/fields.dart';
import '../../core/design/tokens.dart';
import '../../core/design/widgets.dart';
import '../../domain/book.dart';
import '../../domain/ids.dart';
import '../../integrations/cwng/cwng.dart';
import '../../integrations/cwng/credential_store.dart';
import '../../integrations/cwng/opds_parser.dart';
import '../../library/library_importer.dart';
import '../../library/library_service.dart';
import '../../library/library_store.dart';
import '../../library/resumable_downloader.dart';
import '../../sync/conflict_store.dart';
import '../../sync/outbox_repository.dart';
import '../../sync/sync_service.dart';
import '../settings/settings_model.dart';
import '../settings/settings_service.dart';

/// CWNG catalog browsing and download.
///
/// The server URL and username are pre-filled from the saved connection
/// profiles in Settings; the password is read from secure storage and is never
/// rendered. One [SecureTokenStore] is shared by the authenticator, the client
/// and the sync service so an authenticated session survives the page.
class CwngBrowserPage extends StatefulWidget {
  const CwngBrowserPage({
    super.key,
    required this.library,
    this.settings,
    this.credentials,
  });

  final LibraryService library;
  final SettingsService? settings;
  final CwngCredentialStore? credentials;

  @override
  State<CwngBrowserPage> createState() => _CwngBrowserPageState();
}

class _CwngBrowserPageState extends State<CwngBrowserPage> {
  final TokenStore _tokenStore = SecureTokenStore();
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passController = TextEditingController();

  CwngClient? _client;
  CwngAuthState? _authState;
  SyncService? _syncService;
  bool _connecting = false;
  String? _error;
  String? _message;
  String? _activeProfileId;

  List<OpdsBook> _books = <OpdsBook>[];
  List<OpdsLink> _links = <OpdsLink>[];
  String? _currentFeedUrl;
  bool _loadingFeed = false;

  final Map<String, double> _downloadProgress = <String, double>{};
  final Set<String> _downloading = <String>{};

  CwngCredentialStore get _credentialStore =>
      widget.credentials ?? CwngCredentialStore();

  @override
  void initState() {
    super.initState();
    _prefillFromSaved();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _userController.dispose();
    _passController.dispose();
    super.dispose();
  }

  /// Fills the form from the most recent saved connection and silently tries
  /// to resume that session. A failure just leaves the login form showing.
  Future<void> _prefillFromSaved() async {
    final SettingsService? settings = widget.settings;
    if (settings == null) return;
    final List<ConnectionProfile> profiles = await settings.connections();
    if (!mounted || profiles.isEmpty) return;
    final ConnectionProfile profile = profiles.first;
    setState(() {
      _urlController.text = profile.serverUrl;
      _userController.text = profile.username;
    });
    final String? secret = await _credentialStore.read(profile.id);
    if (!mounted || secret == null) return;
    final List<String> parts = utf8.decode(base64Decode(secret)).split(':');
    if (parts.length != 2) return;
    await _connectWith(
      baseUrl: profile.serverUrl,
      username: parts[0],
      password: parts[1],
      profileId: profile.id,
      restoring: true,
    );
  }

  Future<void> _connect() async {
    final String baseUrl = _urlController.text.trim();
    final String username = _userController.text.trim();
    final String password = _passController.text;
    if (baseUrl.isEmpty || username.isEmpty) {
      setState(() => _error = 'Enter server URL and username.');
      return;
    }
    final Uri? uri = Uri.tryParse(baseUrl);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      setState(() => _error = 'Enter a valid server URL, including https://');
      return;
    }
    if (password.isEmpty) {
      // A saved profile may already hold the secret.
      final String? profileId =
          _activeProfileId ?? await _profileIdFor(baseUrl);
      final String? secret = profileId == null
          ? null
          : await _credentialStore.read(profileId);
      if (secret == null) {
        setState(
          () => _error = 'Enter a password or app password.',
        );
        return;
      }
      final List<String> parts = utf8.decode(base64Decode(secret)).split(':');
      if (parts.length != 2 || parts[0] != username) {
        setState(() => _error = 'Enter a password or app password.');
        return;
      }
      await _connectWith(
        baseUrl: baseUrl,
        username: username,
        password: parts[1],
        profileId: profileId,
      );
      return;
    }
    final String? existingProfileId = await _profileIdFor(baseUrl);
    String profileId;
    if (existingProfileId != null) {
      profileId = existingProfileId;
    } else {
      // Create a new profile.
      profileId = 'cwng-${DateTime.now().millisecondsSinceEpoch}';
      final ConnectionProfile profile = ConnectionProfile(
        id: profileId,
        serverUrl: baseUrl,
        username: username,
        label: uri.host,
        lastConnectedAt: DateTime.now(),
      );
      final SettingsService? settings = widget.settings;
      if (settings != null) {
        final List<ConnectionProfile> profiles = await settings.connections();
        profiles.add(profile);
        await settings.saveConnections(profiles);
      }
    }
    await _connectWith(
      baseUrl: baseUrl,
      username: username,
      password: password,
      profileId: profileId,
    );
  }

  /// Finds the saved profile whose server URL matches [baseUrl], so a manual
  /// login can still reuse and refresh the stored secret.
  Future<String?> _profileIdFor(String baseUrl) async {
    final SettingsService? settings = widget.settings;
    if (settings == null) return null;
    final List<ConnectionProfile> profiles = await settings.connections();
    for (final ConnectionProfile profile in profiles) {
      if (profile.serverUrl == baseUrl) return profile.id;
    }
    return null;
  }

  Future<void> _connectWith({
    required String baseUrl,
    required String username,
    required String password,
    String? profileId,
    bool restoring = false,
  }) async {
    setState(() {
      _connecting = true;
      _error = null;
      _message = null;
    });
    try {
      final Dio dio = Dio(BaseOptions(baseUrl: baseUrl));
      final CwngAuthenticator auth = CwngAuthenticator(
        dio: dio,
        tokenStore: _tokenStore,
        baseUrl: baseUrl,
      );
      final CwngAuthState state = await auth.loginBasic(username, password);
      if (profileId != null) {
        await _credentialStore.write(profileId, username, password);
      }
      final CwngClient client = CwngClient(
        baseUrl: baseUrl,
        authenticator: auth,
      );
      client.attachAuth(state);
      SyncService? syncService;
      if (widget.library.store is DriftLibraryStore) {
        final db = (widget.library.store as DriftLibraryStore).database;
        final outbox = OutboxRepository(db);
        final conflicts = ConflictStore(db);
        final provider = CwngLibraryProvider(
          instanceId: ProviderInstanceId(baseUrl),
          authenticator: auth,
          client: client,
        );
        provider.attachAuth(state);
        await provider.refreshCapabilities();
        syncService = SyncService(
          outbox: outbox,
          conflicts: conflicts,
          provider: provider,
          db: db,
          client: client,
        );
        await syncService.recoverOnStartup();
        widget.library.setSyncService(syncService);
      }
      setState(() {
        _authState = state;
        _client = client;
        _syncService = syncService;
        _activeProfileId = profileId;
        _message = 'Connected to $baseUrl';
      });
      // Update lastConnectedAt.
      final SettingsService? settings = widget.settings;
      if (settings != null && profileId != null) {
        final List<ConnectionProfile> profiles = await settings.connections();
        final int idx = profiles.indexWhere(
          (ConnectionProfile p) => p.id == profileId,
        );
        if (idx >= 0) {
          profiles[idx] = ConnectionProfile(
            id: profiles[idx].id,
            serverUrl: profiles[idx].serverUrl,
            username: profiles[idx].username,
            label: profiles[idx].label,
            lastConnectedAt: DateTime.now(),
          );
          await settings.saveConnections(profiles);
        }
      }
      await _loadFeed('/opds');
    } catch (e) {
      if (!restoring) setState(() => _error = 'Connection failed: $e');
    } finally {
      if (mounted) {
        setState(() => _connecting = false);
      }
    }
  }

  Future<void> _loadFeed(String pathOrUrl) async {
    final CwngClient? client = _client;
    if (client == null) return;
    String path = pathOrUrl;
    if (path.startsWith('http')) {
      final Uri uri = Uri.parse(path);
      path = uri.path;
      if (uri.query.isNotEmpty) path = '$path?${uri.query}';
    }
    setState(() {
      _loadingFeed = true;
      _error = null;
    });
    try {
      final Response<String> response = await client.get<String>(path);
      final String body = response.data ?? '';
      final OpdsParser parser = const OpdsParser();
      setState(() {
        _books = parser.parseBooks(body);
        _links = parser.parseLinks(body);
        _currentFeedUrl = path;
        _message = 'Loaded ${_books.length} entries.';
      });
    } catch (e) {
      setState(() => _error = 'Failed to load feed: $e');
    } finally {
      if (mounted) setState(() => _loadingFeed = false);
    }
  }

  Future<void> _downloadBook(OpdsBook book) async {
    final CwngClient? client = _client;
    if (client == null || book.acquisitionUrl == null) return;
    final String key = book.id;
    setState(() {
      _downloading.add(key);
      _downloadProgress[key] = 0;
    });
    try {
      final String url = _resolveUrl(book.acquisitionUrl!);
      final Directory staging = Directory(
        widget.library.downloadDirectory.path,
      );
      if (!await staging.exists()) await staging.create(recursive: true);
      final File target = File(p.join(staging.path, _safeName(book.title)));
      await widget.library.downloader.download(
        Uri.parse(url),
        target: target,
        dio: client.dio,
        onProgress: (DownloadProgress progress) {
          if (mounted && progress.fraction != null) {
            setState(() => _downloadProgress[key] = progress.fraction!);
          }
        },
      );
      final ImportResult result = await widget.library.importer.importFile(
        target,
      );
      if (book.calibreId != null) {
        final Book updated = result.book.copyWith(
          remoteIdentity: RemoteIdentity(
            providerInstanceId: ProviderInstanceId(_client!.baseUrl),
            remoteBookId: RemoteBookId(book.calibreId!),
          ),
        );
        await widget.library.store.save(updated);
        await widget.library.store.upsertSearchIndex(updated);
      }
      try {
        await target.delete();
      } catch (_) {}
      if (mounted) {
        setState(() {
          _downloading.remove(key);
          _downloadProgress.remove(key);
          _message = result.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _downloading.remove(key);
          _downloadProgress.remove(key);
          _error = 'Download failed: $e';
        });
      }
    }
  }

  String _resolveUrl(String href) {
    final String base = _client!.baseUrl;
    if (href.startsWith('http')) return href;
    if (href.startsWith('/')) return '$base$href';
    return '$base/$href';
  }

  String _safeName(String title) {
    final String cleaned = title.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return cleaned.isEmpty ? 'book.epub' : '$cleaned.epub';
  }

  OpdsLink? get _nextLink => _links.where((OpdsLink l) => l.isNext).firstOrNull;
  OpdsLink? get _prevLink =>
      _links.where((OpdsLink l) => l.isPrevious).firstOrNull;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CWNG Library'),
        actions: <Widget>[
          if (_syncService != null)
            SketchIconButton(
              icon: _syncService!.isSyncing ? Icons.sync : Icons.sync_outlined,
              tooltip: 'Sync',
              onPressed: _syncService!.isSyncing
                  ? null
                  : () async {
                      final result = await _syncService!.sync();
                      if (mounted) {
                        setState(() {
                          _message =
                              'Sync: ${result.committed} committed, '
                              '${result.failed} failed, '
                              '${result.conflicts} conflicts';
                        });
                      }
                    },
            ),
          if (_authState != null)
            SketchIconButton(
              icon: Icons.refresh,
              tooltip: 'Reload feed',
              onPressed: _loadingFeed
                  ? null
                  : () => _loadFeed(_currentFeedUrl ?? '/opds'),
            ),
        ],
      ),
      body: _authState == null ? _buildLogin() : _buildCatalog(),
    );
  }

  Widget _buildLogin() {
    return SketchPage(
      child: ListView(
        padding: const EdgeInsets.all(kSpace4),
        children: <Widget>[
          const SketchSectionHeading('Connect to CWNG'),
          const SizedBox(height: kSpace2),
          const Text(
            'CWNG uses HTTP Basic Auth against /opds. Credentials are stored '
            'in secure storage.',
            style: TextStyle(fontSize: 13, height: 1.45, color: kInkMuted),
          ),
          const SizedBox(height: kSpace4),
          SketchTextField(
            label: 'Server URL',
            controller: _urlController,
            hintText: 'https://library.example.org',
            keyboardType: TextInputType.url,
            seedKey: 'cwng-url',
          ),
          const SizedBox(height: kSpace3),
          SketchTextField(
            label: 'Username',
            controller: _userController,
            seedKey: 'cwng-username',
          ),
          const SizedBox(height: kSpace3),
          SketchTextField(
            label: 'Password or app password',
            controller: _passController,
            obscureText: true,
            seedKey: 'cwng-password',
          ),
          const SizedBox(height: kSpace4),
          if (_connecting) const LinearProgressIndicator(),
          if (_error != null) ...<Widget>[
            const SizedBox(height: kSpace2),
            SketchNotice(message: _error!, kind: SketchNoticeKind.error),
          ],
          if (_message != null) ...<Widget>[
            const SizedBox(height: kSpace2),
            SketchNotice(message: _message!),
          ],
          const SizedBox(height: kSpace4),
          SketchButton(
            label: 'Connect',
            icon: Icons.login,
            filled: true,
            expanded: true,
            onPressed: _connecting ? null : _connect,
          ),
        ],
      ),
    );
  }

  Widget _buildCatalog() {
    return SketchPage(
      child: Column(
        children: <Widget>[
          if (_loadingFeed) const LinearProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(kSpace4, kSpace3, kSpace4, 0),
              child: SketchNotice(
                message: _error!,
                kind: SketchNoticeKind.error,
              ),
            ),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(kSpace4, kSpace3, kSpace4, 0),
              child: SketchNotice(message: _message!),
            ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: kSpace2),
              itemCount: _books.length,
              itemBuilder: (BuildContext ctx, int i) {
                final OpdsBook book = _books[i];
                final bool isDownloading = _downloading.contains(book.id);
                return Padding(
                  padding: const EdgeInsets.fromLTRB(
                    kSpace4,
                    kSpace2,
                    kSpace4,
                    0,
                  ),
                  child: SketchSurface(
                    seedKey: 'opds-${book.id}',
                    padding: const EdgeInsets.all(kSpace2),
                    child: Row(
                      children: <Widget>[
                        Icon(
                          book.isNavigation
                              ? Icons.folder_outlined
                              : Icons.menu_book_outlined,
                          size: 22,
                          color: kInkMuted,
                        ),
                        const SizedBox(width: kSpace3),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                book.title,
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w600,
                                  color: kInk,
                                ),
                              ),
                              if (book.authors.isNotEmpty)
                                Text(
                                  book.authors.join(', '),
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: kInkMuted,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (book.isDownloadable)
                          isDownloading
                              ? SizedBox(
                                  width: 48,
                                  child: LinearProgressIndicator(
                                    value: _downloadProgress[book.id],
                                  ),
                                )
                              : SketchIconButton(
                                  icon: Icons.download_outlined,
                                  tooltip: 'Download ${book.title}',
                                  onPressed: () => _downloadBook(book),
                                )
                        else if (book.isNavigation)
                          SketchIconButton(
                            icon: Icons.chevron_right,
                            tooltip: 'Open ${book.title}',
                            onPressed: () => _loadFeed(book.navigationUrl!),
                          )
                        else
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: kSpace2),
                            child: SketchBadge(label: 'Unavailable'),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              decoration: const BoxDecoration(
                color: kPaperSurface,
                border: Border(top: BorderSide(color: kBorderFaint)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: kSpace3),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  if (_prevLink != null)
                    TextButton(
                      onPressed: () => _loadFeed(_prevLink!.href),
                      child: const Text('Previous'),
                    )
                  else
                    const SizedBox.shrink(),
                  Text(
                    '${_books.length} entries',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: kInkMuted,
                    ),
                  ),
                  if (_nextLink != null)
                    TextButton(
                      onPressed: () => _loadFeed(_nextLink!.href),
                      child: const Text('Next'),
                    )
                  else
                    const SizedBox.shrink(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
