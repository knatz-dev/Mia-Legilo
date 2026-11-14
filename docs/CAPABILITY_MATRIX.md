# CWNG Capability Matrix

Status values: `unknown` (default, unverified), `unsupported`, `readOnly`, `writeOnly`, `readWrite`.

| Resource | Operation | State | Evidence |
|---|---|---|---|
| books | browse (OPDS) | readOnly (verified: /opds/books returns Atom feed on library.knatz.dev) | live probe 2026-11-14 |
| books | fetch single | unknown | not verified |
| books | create/update metadata | unknown | not verified (never assumed writable) |
| downloads | fetch file (OPDS acquisition) | readOnly (verified: /opds/books reachable; acquisition links present) | live probe 2026-11-14 |
| progress | read | unknown | not verified |
| progress | write | unknown | not verified |
| status | read | unknown | not verified |
| status | write | unknown | not verified |
| shelves | read | unknown | not verified |
| shelves | write | unknown | not verified |
| bookmarks | read | unknown | not verified |
| bookmarks | write | unknown | not verified |
| annotations | read | unknown | not verified |
| annotations | write | unknown | not verified |

## Rules
- Default to `unknown`; upgrade only with verification evidence.
- Writes are never assumed; unsupported writes remain local-only.
- Status/position mappings require verified equivalent provider values (INT-005).
- Percentage is never an authoritative merge rule (SYN-006).
