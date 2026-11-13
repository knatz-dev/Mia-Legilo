# Broader design interview — decisions in progress

These are user-confirmed interview answers, not a replacement for SPEC.md or ARCHITECTURE.md. The full design has not yet received shared-understanding approval. No implementation is authorized by this record.

## Confirmed product direction

- Existing platform and reader-engine choices may be reconsidered; replacements are not selected.
- Reading and personal library organization have equal prominence.
- Initial audience: the user's workflow plus a small group of self-hosted Calibre users.
- Named launch devices, preserving the user's descriptions: `boox Note Air 4c` and `Ulephone Amorpad`. Whether both run Mia-Legilo remains unconfirmed; moving to the next question was not acceptance.
- Initial format: EPUB only.
- Continuous scrolling is required at launch and takes priority; pagination may follow later.
- Normal launch opens the library with Continue Reading and shelves.
- Server catalog metadata remains read-only from Mia-Legilo; personal organization is distinct from catalog administration.

## Persistence and synchronization

- CWNG is the server-side authority for catalog and personal organization.
- No second authoritative server-side database. Any additional compatibility service is temporary, has no separate persistent store, and must be removable when CWNG supplies the feature. Feasibility is still under investigation.
- A small local database is accepted for cached metadata, local reading positions and device preferences; cached organization is read-only offline. Downloaded EPUB assets are separate from the database.
- Shelves, memberships and reading status must synchronize across devices at launch.
- Progress and bookmark synchronization remain provider-capability-dependent; local reading state must remain durable.
- Initial library and organization-sync setup is mandatory before use. Setup requires verifying a capable service; the second device may join later.
- After setup, downloaded books remain readable offline. Shelf, membership and reading-status edits are blocked offline, including automatic status changes.
- User's reason for deferring offline organization edits: avoid offline-to-online synchronization hassle at launch; offline editing may be considered later. This does not eliminate concurrent online edits or uncertain outcomes after interrupted requests.
- Conflicting reading-status or shelf-membership edits require user resolution rather than timestamp-based or automatic add/remove winners. Reading must remain available during resolution.
- The earlier question about two independently available services is superseded by the single-authority requirement, not answered by assuming either proposed availability policy.

## Reader appearance

- Appearance preferences are device-specific.
- Device-wide reader defaults support explicit per-book overrides.
- Changes are previews until Apply; Apply saves, Cancel discards.
- Q25: dismissing without Apply discards unapplied changes. This includes Close, Android Back and outside-tap dismissal where offered. Restore the saved appearance without losing reading position.
- Backgrounding behavior was recommended separately but has not been explicitly confirmed.
- Q26: app appearance and reader appearance are separate; per-book appearance changes do not recolor the library.
- Q27: appearance editing opens in This book scope, with an explicit Device defaults switch. Reset for a book removes its override and restores device defaults; edits remain preview-only until Apply.

## Library presentation

- Q28 originally agreed to a unified imported/CWNG library; Q31 supersedes the independent-import portion: Mia-Legilo is a CWNG frontend, not a general-purpose reader. Books with no equivalent CWNG entry must not be available.
- Downloaded CWNG books remain readable offline as previously agreed. Behavior after confirmed server deletion/access revocation, and whether matching local files may supply a CWNG book's offline copy, remain undecided.
- Downloaded-only filtering remains applicable. Source filters are only relevant if multiple CWNG sources are later supported.
- Q29: use CWNG's five reading statuses: Unread, Currently reading, Finished, Did not finish and On hold. Want to Read is a normal shelf, not a sixth status.
- Q30: expose the provider's destructive Unread operation as Reset to Unread with an explicit warning that it clears stored reading positions and require confirmation. Never invoke this reset automatically.
- Q32: launch EPUB files come through CWNG. Remove standalone Import/Open EPUB actions; users add books through CWNG and download them in Mia-Legilo.
- Q33: after authoritative confirmation of server deletion or access revocation, make the downloaded book unavailable while retaining reading history for possible recovery. Connection failure or incomplete catalog refresh is never evidence of deletion. Physical file retention/deletion policy is not yet decided.

## Open branches

- Actual CWNG capabilities, deployed version, temporary adapter feasibility and retirement boundary.
- Whether the second device runs Mia-Legilo; exact device model/platform if needed for validation.
- Library source presentation, theme scope, detailed reader interaction and recovery behavior.
- Technical platform and renderer selection against device-tested continuous-scrolling gates.
- Final specification reconciliation and overall shared-understanding confirmation.
