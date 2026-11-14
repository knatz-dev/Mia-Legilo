# Test Data and Fixture Policy

- Fixtures live under `test/fixtures/` and are committed to the repository.
- Never commit real user data, credentials, tokens, or personal information.
- All CWNG request/response fixtures must be sanitized: replace auth headers, cookies, tokens, and personal identifiers with placeholders.
- Fixtures must be deterministic and version-pinned to a documented CWNG version.
- Add a redaction review checklist before merging any new fixture.
- Network fakes must implement the same interfaces as real clients; tests must not hit live servers in PR CI.
- Clocks and randomness must be injectable (see `lib/core/clock.dart`).
