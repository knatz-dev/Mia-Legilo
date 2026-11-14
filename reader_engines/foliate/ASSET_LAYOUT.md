# Asset Layout

```
reader_engines/foliate/
  foliate-js/          # vendored source (pinned commit)
  assets/              # built output loaded by WebView (generated, gitignored or committed per release policy)
  build.ps1            # reproducible build script
  README.md
  PATCH_LEDGER.md
  SBOM.md
```

`assets/` is produced by the rollup build and consumed by the Flutter app via pubspec assets.
