import 'dart:io';

import 'package:dio/dio.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

import '../../integrations/cwng/cwng.dart';
import '../../integrations/cwng/opds_parser.dart';
import '../../library/library_importer.dart';
import '../../library/library_service.dart';
import '../../library/resumable_downloader.dart';

class CwngBrowserPage extends StatefulWidget {
  const CwngBrowserPage({super.key, required this.library});

  final LibraryService library;

  @override
  State<CwngBrowserPage> createState() => _CwngBrowserPageState();
}

class _CwngBrowserPageState extends State<CwngBrowserPage> {
  final TextEditingController _urlController =
      TextEditingController(text: 'https://library.knatz.dev');
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passController = TextEditingController();

  CwngClient? _client;
  CwngAuthState? _authState;
  bool _connecting = false;
  String? _error;
  String? _message;

  List<OpdsBook> _books = <OpdsBook>[];
  List<OpdsLink> _links = <OpdsLink>[];
  String? _currentFeedUrl;
  bool _loadingFeed = false;

  final Map<String, double> _downloadProgress = <String, double>{};
  final Set<String> _downloading = <String>{};

  @override
  void dispose() {
    _urlController.dispose();
    _userController.dispose();
    _passController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final String baseUrl = _urlController.text.trim();
    final String username = _userController.text.trim();
    final String password = _passController.text;
    if (baseUrl.isEmpty || username.isEmpty) {
      setState(() => _error = 'Enter server URL and username.');
      return;
    }
    setState(() {
      _connecting = true;
      _error = null;
      _message = null;
    });
    try {
      final Dio dio = Dio(BaseOptions(baseUrl: baseUrl));
      final CwngAuthenticator auth = CwngAuthenticator(
        dio: dio,
        tokenStore: InMemoryTokenStore(),
        baseUrl: baseUrl,
      );
      final CwngAuthState state = await auth.loginBasic(username, password);
      final CwngClient client = CwngClient(baseUrl: baseUrl, authenticator: auth);
      client.attachAuth(state);
      setState(() {
        _authState = state;
        _client = client;
        _message = 'Connected to $baseUrl';
      });
      await _loadFeed('/opds');
    } catch (e) {
      setState(() => _error = 'Connection failed: $e');
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<void> _loadFeed(String pathOrUrl) async {
    final CwngClient? client = _client;
    if (client == null) return;
    // Normalize to a path for client.get (which prepends baseUrl).
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
      final ImportResult result = await widget.library.importer.importFile(target);
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

  OpdsLink? get _nextLink =>
      _links.where((OpdsLink l) => l.isNext).firstOrNull;
  OpdsLink? get _prevLink =>
      _links.where((OpdsLink l) => l.isPrevious).firstOrNull;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CWNG Library'),
        actions: <Widget>[
          if (_authState != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Reload feed',
              onPressed: _loadingFeed ? null : () => _loadFeed(_currentFeedUrl ?? '/opds'),
            ),
        ],
      ),
      body: _authState == null ? _buildLogin() : _buildCatalog(),
    );
  }

  Widget _buildLogin() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        TextField(
          controller: _urlController,
          decoration: const InputDecoration(
            labelText: 'Server URL',
            hintText: 'https://library.knatz.dev',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _userController,
          decoration: const InputDecoration(
            labelText: 'Username',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _passController,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Password',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        if (_connecting) const LinearProgressIndicator(),
        if (_error != null)
          Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(_error!),
            ),
          ),
        if (_message != null)
          Card(
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(_message!),
            ),
          ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          icon: const Icon(Icons.login),
          label: const Text('Connect'),
          onPressed: _connecting ? null : _connect,
        ),
        const SizedBox(height: 16),
        const Text(
          'CWNG uses HTTP Basic Auth against /opds. '
          'Credentials are stored in secure storage.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildCatalog() {
    return Column(
      children: <Widget>[
        if (_loadingFeed) const LinearProgressIndicator(),
        if (_error != null)
          Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(_error!),
            ),
          ),
        if (_message != null)
          Card(
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(_message!),
            ),
          ),
        Expanded(
          child: ListView.builder(
            itemCount: _books.length,
            itemBuilder: (BuildContext ctx, int i) {
              final OpdsBook book = _books[i];
              final bool isDownloading = _downloading.contains(book.id);
              return Card(
                child: ListTile(
                  leading: Icon(book.isNavigation
                      ? Icons.folder_outlined
                      : Icons.menu_book_outlined),
                  title: Text(book.title),
                  subtitle: Text(book.authors.join(', ')),
                  onTap: book.isNavigation
                      ? () => _loadFeed(book.navigationUrl!)
                      : null,
                  trailing: book.isDownloadable
                      ? (isDownloading
                          ? SizedBox(
                              width: 48,
                              child: LinearProgressIndicator(
                                value: _downloadProgress[book.id],
                              ),
                            )
                          : IconButton(
                              icon: const Icon(Icons.download),
                              tooltip: 'Download',
                              onPressed: () => _downloadBook(book),
                            ))
                      : (book.isNavigation
                          ? const Icon(Icons.chevron_right)
                          : const Icon(Icons.block)),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
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
              Text('${_books.length} entries'),
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
      ],
    );
  }
}

class InMemoryTokenStore implements TokenStore {
  final Map<String, String> _store = <String, String>{};

  @override
  Future<String?> read(String key) async => _store[key];

  @override
  Future<void> write(String key, String value) async {
    _store[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _store.remove(key);
  }
}
