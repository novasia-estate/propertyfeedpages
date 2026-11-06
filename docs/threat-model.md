# Boundaries

A local consistency checker, not a crawler or security attestation. It executes no input code, follows no URLs and authenticates no producer.

The decoder needs memory for the bounded JSON input. Audit uses maps and is approximately linear in page count plus ID occurrences. Reports omit input-sensitive values; that does not make original captures safe to publish. Error messages also omit source values.

HTML escapes interpolations and embeds no JavaScript. A caller may directly construct a Report, so escaping is tested outside audit-generated values.

A malicious producer can provide self-consistent false data. Consistency proves neither ownership, availability, content accuracy nor real-world completeness. Unicode IDs are compared exactly without fuzzy identity matching.
