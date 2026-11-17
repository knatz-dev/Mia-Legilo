# Mia Legilo code review (main @ 8973dac)

CWNG credentials are dropped in the settings dialog before any store is touched, and the browser never reads a saved secret back. A local widget test confirmed the saved connection JSON contains the username and URL and does not contain the password. `flutter analyze` is clean. `flutter test` is 96 passed, 1 failed (a gitignored EPUB fixture).

Reviewed `8973dac` (`e45afc2..8973dac`). No commits were created and nothing was pushed. The throwaway test was deleted afterward.

## 1. CWNG credentials bug

The password is discarded in `_ConnectionEditDialog._save`. It is validated, then omitted from the object that is persisted.

```275:302:lib/features/settings/connections_page.dart
  void _save() {
    final String url = _url.text.trim();
    final String user = _user.text.trim();
    final String password = _pass.text;
    // ... empty-password check for a new profile ...
    Navigator.of(context).pop(
      ConnectionProfile(
        id: widget.existing?.id ??
            'cwng-${uri.host}-${DateTime.now().microsecondsSinceEpoch}',
        serverUrl: url,
        username: user,
        label: ...,
        lastConnectedAt: widget.existing?.lastConnectedAt,
      ),
    );
  }
```

`ConnectionProfile` has no password field. `toJson()` is explicitly non-secret (`lib/features/settings/settings_model.dart:274-281`). `_add` / `_edit` only call `SettingsService.saveConnections` (`lib/features/settings/connections_page.dart:42-56` and `:132-136`), which writes that JSON to the settings table. The edit hint “leave blank to keep” has nothing to keep.

`SecureTokenStore` (`lib/integrations/cwng/secure_token_store.dart:4-18`) is never constructed anywhere in `lib/`. Legacy migration is not involved: `SettingsService` only migrates `reader.settings` and `library.autoStartReading` (`lib/features/settings/settings_service.dart:16-20`, `:83-111`).

Two further breaks stop a later reconnect from recovering a secret:

1. Settings are written to a different store than the library. `settingsProvider` uses `LibraryService.bootstrap()` (`lib/main.dart:35-44`), which builds a new `MemoryLibraryStore` and sets `closeDatabase` to null (`lib/library/library_service.dart:47-56`, `lib/library/library_store.dart:612-616`). `LibraryScreen` opens a separate Drift database with `LibraryService.open()` (`lib/main.dart:296-301`). A profile saved in Settings is gone after process death, and the library screen never sees it.
2. The browser does not read profiles or secure storage. `_connect` builds a fresh `InMemoryTokenStore` (`lib/features/cwng/cwng_browser_page.dart:77-83` and `:464-481`). `loginBasic` writes the base64 basic token only into that map (`lib/integrations/cwng/cwng_auth.dart:98-108`). The page starts logged out on every visit. Authenticated downloads and `SyncService` use that same in-memory client, so they lose the token when the library screen is disposed.

Evidence: a local widget test filled the dialog with username `alice` and password `s3cret-app-password`, tapped Save, and read `settings.connections`. The JSON contained `alice` and the server URL and did not contain the password. A second test showed `settingsProvider`’s store is a `MemoryLibraryStore` with `closeDatabase == null`.

Proposed fix:

```diff
diff --git a/lib/integrations/cwng/credential_store.dart b/lib/integrations/cwng/credential_store.dart
new file mode 100644
--- /dev/null
+++ b/lib/integrations/cwng/credential_store.dart
@@ -0,0 +1,31 @@
+import 'dart:convert';
+
+import 'secure_token_store.dart';
+import 'token_store.dart';
+
+/// Basic-auth secret for one connection profile. Keyed by profile id so a
+/// second server does not overwrite the first. The password never enters
+/// Drift or ConnectionProfile.toJson().
+class CwngCredentialStore {
+  CwngCredentialStore({TokenStore? store}) : _store = store ?? SecureTokenStore();
+
+  final TokenStore _store;
+
+  String _key(String profileId) => 'cwng.basic.$profileId';
+
+  Future<void> write(String profileId, String username, String password) {
+    final String token = base64Encode(utf8.encode('$username:$password'));
+    return _store.write(_key(profileId), token);
+  }
+
+  Future<String?> read(String profileId) => _store.read(_key(profileId));
+
+  Future<void> delete(String profileId) => _store.delete(_key(profileId));
+}
diff --git a/lib/features/settings/connections_page.dart b/lib/features/settings/connections_page.dart
@@ -14,8 +14,11 @@ class ConnectionSettingsPage extends StatefulWidget {
-  const ConnectionSettingsPage({super.key, required this.settings});
+  const ConnectionSettingsPage({
+    super.key,
+    required this.settings,
+    this.credentials,
+  });
 
   final SettingsService settings;
+  final CwngCredentialStore? credentials;
+
+  CwngCredentialStore get _credentials =>
+      credentials ?? CwngCredentialStore();
@@ -46,6 +49,7 @@ class _ConnectionSettingsPageState extends State<ConnectionSettingsPage> {
-    final ConnectionProfile? profile = await showDialog<ConnectionProfile>(
+    final _Draft? draft = await showDialog<_Draft>(
       context: context,
       builder: (_) => const _ConnectionEditDialog(),
     );
-    if (profile == null) return;
+    if (draft == null) return;
+    if (draft.password.isNotEmpty) {
+      await widget._credentials.write(
+        draft.profile.id, draft.profile.username, draft.password);
+    }
     setState(() {
       _profiles = <ConnectionProfile>[
-        ..._profiles.where((ConnectionProfile p) => p.id != profile.id),
-        profile,
+        ..._profiles.where((ConnectionProfile p) => p.id != draft.profile.id),
+        draft.profile,
       ];
     });
     await _persist();
@@ -97,6 +106,7 @@ class _ConnectionSettingsPageState extends State<ConnectionSettingsPage> {
     if (confirmed != true) return;
+    await widget._credentials.delete(profile.id);
     setState(() => _profiles = _profiles.where((p) => p.id != profile.id).toList());
     await _persist();
@@ -275,8 +285,10 @@ class _ConnectionEditDialogState extends State<_ConnectionEditDialog> {
-    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
+    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
       setState(() => _error = 'Enter a valid server URL, including https://');
       return;
     }
@@ -292,14 +304,14 @@ class _ConnectionEditDialogState extends State<_ConnectionEditDialog> {
-    Navigator.of(context).pop(
-      ConnectionProfile(
+    Navigator.of(context).pop(_Draft(
+      profile: ConnectionProfile(
         id: widget.existing?.id ??
             'cwng-${uri.host}-${DateTime.now().microsecondsSinceEpoch}',
         serverUrl: url,
         username: user,
         label: _label.text.trim().isEmpty ? uri.host : _label.text.trim(),
         lastConnectedAt: widget.existing?.lastConnectedAt,
-      ),
-    );
+      ),
+      password: password,
+    ));
diff --git a/lib/main.dart b/lib/main.dart
@@ -35,12 +35,16 @@ import 'sync/sync_service.dart';
-final libraryProvider = Provider<LibraryService>((ref) {
-  final LibraryService service = LibraryService.bootstrap();
-  ref.onDispose(service.close);
-  return service;
-});
-
-final settingsProvider = Provider<SettingsService>((ref) {
-  return SettingsService(ref.watch(libraryProvider));
-});
+final libraryProvider = FutureProvider<LibraryService>((ref) async {
+  final LibraryService service = await LibraryService.open();
+  ref.onDispose(service.close);
+  return service;
+});
+
+final settingsProvider = Provider<SettingsService>((ref) {
+  return SettingsService(ref.watch(libraryProvider).requireValue);
+});
```

`LibraryScreen` then has to watch that same `libraryProvider` and stop calling `LibraryService.open()` itself (`lib/main.dart:296-297`), and the shell has to keep that service alive across the Library/Settings switch (today the switch disposes the screen and closes the database, `lib/main.dart:110-115` and `:268-273`).

The browser has to load `settings.connections()`, read `CwngCredentialStore.read(profile.id)` when the password field is empty, and pass one `SecureTokenStore` into `CwngAuthenticator` instead of `InMemoryTokenStore()` (`lib/features/cwng/cwng_browser_page.dart:77-83`). On the next visit, call `authenticator.restore()` before showing the login form. `loginBasic` already persists the basic token into whatever store it is given (`lib/integrations/cwng/cwng_auth.dart:107-108`); that store has to be the secure one, and the key has to include the profile id. The global key `cwng_access_token` collides across profiles (CON-005).

## 2. Other findings

### Critical

**EPUB documents run with access to the reader bridge.** `paginator.js:804` sets the section iframe to `sandbox="allow-same-origin allow-scripts"`. With both flags, the frame is the parent origin, so script inside an EPUB can reach `FoliateBridge` and the loopback book URLs. That is the case `docs/ARCHITECTURE.md` forbids (“No EPUB-supplied script may execute with bridge privileges”). The comment above the attribute cites a WebKit event bug; Android WebView is Chromium, so `allow-scripts` may be unnecessary there. I did not runtime-test a malicious EPUB. Drop `allow-scripts` on Android, or move the bridge off any window the iframe can see.

### High

**Status sync never leaves the device.** After connect, the browser calls `refreshCapabilities()` without `authenticate()`, and `CwngLibraryProvider.refreshCapabilities` returns immediately while `_auth` is null (`lib/integrations/cwng/cwng_provider.dart:38-39`, browser call at `lib/features/cwng/cwng_browser_page.dart:94-99`). Capabilities stay `unknown`. `enqueueStatusChange` and the outbox drain then gate on `CapabilityResource.books`, which the probe sets to `readOnly` even when `CapabilityResource.status` is `readWrite` (`lib/sync/sync_service.dart:224-230` and `:273-278`, probe at `lib/integrations/cwng/cwng_capability_probe.dart:21-24` and `:49-54`). A local test confirmed both: an unauthenticated refresh stays `unknown`, and enqueue with `books=readOnly` / `status=readWrite` inserts 0 outbox rows, while `books=readWrite` inserts a row even if status is `unknown`. Local status is still saved (`lib/main.dart:444`). Set `_auth` from the basic login before probing, and gate `readingStatus` on `CapabilityResource.status`. The existing capability tests only check `isWritable` on a hand-built matrix (`test/sync/sync_fault_injection_test.dart:59-78`); they never call `enqueueStatusChange`.

**Every Settings-tab value is stored in the bootstrap memory store and is not applied live.** Same split as above. Appearance is loaded once (`lib/main.dart:69-72`) and `AppearanceSettingsPage._save` only writes the service (`lib/features/settings/settings_pages.dart:238-241`), so it never updates `appearanceProvider`. `darkTheme` is `buildMiaLegiloTheme()`, which is `ColorScheme.light` (`lib/main.dart:81-82`, `lib/core/design/theme.dart:51-52`). Reader defaults opened from the reader use the Drift library (`lib/features/reader/reader_page.dart:88-89`); Settings → Reader uses the memory provider. Share one `LibraryService.open()` and, after `saveAppearance`, assign `appearanceProvider`.

**In-flight outbox entries are stranded (SYN-002).** `pending()` returns only `pending` and `failed` (`lib/sync/outbox_repository.dart:75-79`). `recoverOnStartup` exists (`lib/sync/sync_service.dart:59-66`) and is never called from `lib/`. `test/sync/restart_recovery_test.dart:38-43` reimplements the loop instead of calling the method. A kill after `markInFlight` (`lib/sync/sync_service.dart:119`) leaves the row out of every later drain. Call `recoverOnStartup` when the sync service is created, and include `inFlight` in that recovery.

**Book text is printed to logcat.** Each section load posts the first 160 characters (`assets/foliate/host.html:109-113`), and the engine prints them (`lib/reader_engines/foliate/foliate_engine.dart:326-328`). `RedactingLogger` is not on this path. Drop the `text` field from the bridge message.

**Basic auth can be sent over cleartext HTTP.** The connection dialog accepts any scheme with a host (`lib/features/settings/connections_page.dart:280-282`). The browser does not check the scheme (`lib/features/cwng/cwng_browser_page.dart:63-83`). The manifest sets `android:usesCleartextTraffic="true"` (`android/app/src/main/AndroidManifest.xml:6`), which the loopback Foliate server needs. Require `https` for CWNG and limit cleartext to `127.0.0.1` in a network security config. Saving a connection also never probes the server, so CON-001’s auth / TLS / network / incompatible-server distinction is absent.

**The open EPUB is served on device-wide loopback with no secret.** `FoliateServer` binds `127.0.0.1` and serves `/books/<id>` to any caller, with `Access-Control-Allow-Origin: *` (`lib/reader_engines/foliate/foliate_server.dart:49-63`, `:73`, `:140-156`). On Android, other apps can connect to that port. Put an unguessable token in the book URL and drop the wildcard CORS header.

### Medium

**Conflict detection compares the status being written with the current remote status, not a revision.** When `observedRemoteRevision` is set, any difference creates a conflict and the write is skipped (`lib/sync/sync_service.dart:132-163`). The lookup uses `entry.bookId` (the local id) rather than `payload['remoteBookId']` (`:134-138` versus `:293`). Today’s caller does not pass a revision (`lib/main.dart:447-454`), so this branch does not run yet. Compare a stored remote revision, and fetch by the remote id.

**The capability probe writes to the server.** It POSTs `{'status': 'unread'}` to `/api/v1/books/probe/read-status` (`lib/integrations/cwng/cwng_capability_probe.dart:41-49`). A 200 is treated as success and has already mutated a book whose id is `probe`, if one exists. Probe with `HEAD` or a request that the server documents as non-mutating.

**`logout()` leaves `cwng_auth_scheme` behind.** `loginBasic` writes `cwng_auth_scheme=basic` (`lib/integrations/cwng/cwng_auth.dart:107-108`). `logout()` deletes the token keys and not the scheme (`:149-153`). A later bearer login goes through `_persist`, which does not reset the scheme (`:155-162`), so `restore()` can label a bearer token as basic (`:123-124`). Delete the scheme on logout and set it to `bearer` in `_persist`.

**Renderer errors reload the book.** Any `onWebResourceError` calls `recover()`, which loads the book again (`lib/features/reader/reader_page.dart:110-117`, `lib/reader_engines/foliate/foliate_engine.dart:28-34` and `:257-284`). A missing subresource can restart the book up to three times, and a failure during recovery calls `recover()` again with no in-flight guard. Recover only from a renderer crash, and ignore overlapping attempts.

**Reduced motion is stored and never read.** It is copied onto `ReaderSettings` (`lib/features/reader/reader_page.dart:97`) and no widget reads it. Sketch motion durations stay `kMotionFast` / `kMotionBase` (`lib/core/design/tokens.dart:64-65`). For e-ink, thread the flag into the painters and the reader, and have appearance changes update `appearanceProvider` (see the High item above).

**Switching tabs destroys the library.** The shell swaps the body (`lib/main.dart:110-115`), and `LibraryScreen.dispose` cancels the download and closes the database (`:268-273`). An in-progress import is aborted, scroll and search state are dropped, and the CWNG `SyncService` held by that service is dropped with its in-memory token. Keep the opened library above the tab switch.

**`syncCatalog`, `refreshMetadata`, and `detectDeletions` are stubs and have no callers.** `syncCatalog` only counts `<entry>` substrings (`lib/sync/sync_service.dart:70-79`). `refreshMetadata` returns `true` without writing (`:323-338`). `detectDeletions` returns an empty list (`:344-348`). A success result here would report a sync that did not happen (SYN-012, SYN-019).

### Low

**Default CWNG URL is committed.** The browser field starts as `https://library.knatz.dev` (`lib/features/cwng/cwng_browser_page.dart:34-36`). `docs/LIVE_TESTING.md` says not to commit server-specific config. Start the field empty and use the saved profile.

**`go_router` is a dependency and is unused.** Settings routes are anonymous `MaterialPageRoute`s (`lib/features/settings/settings_pages.dart:186`) while the page comment calls them directly linkable.

**`LibraryService.bootstrap()` gives the importer a second `MemoryLibraryStore`.** (`lib/library/library_service.dart:47-54`). Anything imported through that importer is invisible to `service.store`. The running app currently uses `bootstrap()` only for settings.

**`CwngBrowserPage` declares its own `InMemoryTokenStore`.** (`lib/features/cwng/cwng_browser_page.dart:467-481`), duplicating `lib/integrations/cwng/token_store.dart:9-19`.

**Reader-settings sliders fire an unsequenced save on every change.** (`lib/features/settings/settings_pages.dart:601-602`). On the Drift store used by the reader, overlapping `insertOnConflictUpdate` calls can commit an older value last. Serialize writes per key.

## 3. Analyzer and tests

Flutter 3.50.0 / Dart 3.14.0 (the CI pin).

`flutter analyze`: **No issues found** (8.3s).

`flutter test`: **96 passed, 1 failed.**

The failure is `test/library/epub_inspector_test.dart` “reads a real Gutenberg EPUB”: `PathNotFoundException` for `test/fixtures/epub/84.epub`. That path is gitignored (`.gitignore` line 125), so the file is not in this checkout. The other inspector cases passed. The live CWNG probe was skipped because `CWNG_USERNAME` / `CWNG_PASSWORD` are unset.

I did not install or smoke-test an emulator build. This pass is review-only.