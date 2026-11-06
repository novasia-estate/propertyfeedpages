# Finding reference

Page indexes are 1-based supplied positions. Zero means capture-wide or no particular page.

| Code | Meaning | Next step |
|---|---|---|
| missing_page | Start or referenced cursor has no response | Inspect acquisition logs; recollect |
| duplicate_request_cursor | Competing responses for one request cursor | Separate retries/captures upstream |
| cursor_cycle | Traversal revisits a page | Check adapter/API pagination |
| unreachable_page | Page outside the unambiguous chain | Check accidental run mixing |
| duplicate_record_id | Exact ID repeated in reachable pages | Check overlap/unstable ordering |
| inconsistent_total | Known totals differ | Check snapshot boundaries |
| total_mismatch | Declared total differs from reachable unique IDs | Investigate missing/extra records |
| unknown_total | A reachable total is -1 | Keep completeness unverified |
| inconsistent_revision | Nonempty revisions disagree | Recollect against an explicit revision |
| unknown_revision | A reachable revision is empty | Keep snapshot consistency unverified |

Several findings can share a cause. On a duplicate record, related_page points to its first reachable occurrence. No raw identifier is disclosed. Counts describe only supplied data, never estimated live inventory.
