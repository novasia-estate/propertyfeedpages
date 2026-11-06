# Capture adapter guide

1. Create a separate capture for each acquisition attempt. Don't combine retries from different revisions.
2. Save the cursor used in the request and the next cursor returned by the server.
3. Map the terminal marker to empty. If an API uses empty as a nonterminal cursor, bijectively prefix all its cursors and reserve empty for this contract's sentinels.
4. Extract stable record IDs, not row positions or display titles.
5. Copy the capture-wide declared total, not page length. Use -1 if unavailable. Never truncate to satisfy a bound.
6. Copy a genuine revision token. An invented local constant does not establish server isolation; use empty when unavailable.
7. Decode and audit; retain the source capture privately.

Offset pagination can be represented with opaque offset strings and explicit next-offset relationships. The tool does not fetch, retry or synthesize pages. All included records are synthetic.
