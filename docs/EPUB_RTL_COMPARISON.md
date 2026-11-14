# epub_rtl Comparison (Phase 2)

**Status:** Comparative evidence only; not selected.

## Summary
`epub_rtl` was evaluated as a comparative candidate. Foliate-js remains the selected renderer under ADR-001.

## Observed differences
- Percentage reporting in epub_rtl conflates display percentage with semantic location; must be treated as approximate only.
- Cross-chapter scrolling continuity not verified to the same standard.
- Accessibility and bridge isolation weaker.

## Conclusion
epub_rtl does not meet the hard gates; Foliate-js remains selected. Reopen ADR-001 only if Foliate-js fails a hard gate.
