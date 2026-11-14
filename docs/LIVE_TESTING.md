# Live CWNG Testing

Target server: `https://library.knatz.dev` (do not commit credentials or server-specific config).

## Environment variables

```powershell
$env:CWNG_BASE_URL = "https://library.knatz.dev"
$env:CWNG_USERNAME = "your-username"
$env:CWNG_PASSWORD = "your-password"
```

## Run live integration test

```powershell
flutter test integration_test/cwng_live_test.dart
```

The test skips automatically if `CWNG_USERNAME`/`CWNG_PASSWORD` are not set.

## Rules
- Never commit credentials, tokens, or server-specific config.
- Keep `.env` and `integration_test/config.local.json` gitignored.
- Sanitize any captured fixtures before committing (see TEST_DATA_POLICY.md).
