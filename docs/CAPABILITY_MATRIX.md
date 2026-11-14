# CWNG Capability Matrix

Status values: `unknown` (default, unverified), `unsupported`, `readOnly`, `writeOnly`, `readWrite`.

| Resource | Operation | State | Evidence |
|---|---|---|---|
| books | browse (paged) | unknown (provisional readOnly if /api/books reachable) | CwngCapabilityProbe |
| books | fetch single | unknown | not verified |
| books | create/update metadata | unknown | not verified (never assumed writable) |
| downloads | fetch file | unknown (provisional readOnly if download endpoint reachable) | CwngCapabilityProbe |
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
