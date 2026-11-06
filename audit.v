module propertyfeedpages

// audit is deterministic, does not mutate input and never returns raw cursors/IDs.
pub fn audit(c Capture) !Report {
	if c.schema_version != 1 { return error('unsupported schema_version') }
	if c.pages.len == 0 || c.pages.len > 10000 {
		return error('pages must contain 1..10000 entries')
	}
	mut nr := 0
	for p in c.pages {
		if p.total < -1 || p.total > 100000 {
			return error('total must be -1 (unknown) or nonnegative')
		}
		if p.request_cursor.len > 4096 || p.next_cursor.len > 4096 || p.revision.len > 1024 {
			return error('metadata length limit exceeded')
		}
		nr += p.record_ids.len
		if nr > 100000 { return error('record limit exceeded') }
		for id in p.record_ids {
			if id.trim_space() == '' || id.len > 1024 {
				return error('record IDs must be nonblank and at most 1024 bytes')
			}
		}
	}
	mut findings := []Finding{}
	mut requests := map[string]int{}
	mut ambiguous := map[string]bool{}
	for i, p in c.pages {
		if old := requests[p.request_cursor] {
			findings << Finding{'duplicate_request_cursor', i + 1, old + 1}
			ambiguous[p.request_cursor] = true
		} else {
			requests[p.request_cursor] = i
		}
	}
	mut chain := []int{}
	mut visited := map[int]bool{}
	mut cursor := ''
	mut terminal := false
	mut ids := map[string]int{}
	mut count := 0
	mut totals := map[int]bool{}
	mut revisions := map[string]bool{}
	mut unknown_revisions := 0
	mut unknown_totals := 0
	for {
		if ambiguous[cursor] { break
		 }
		idx := requests[cursor] or {
			findings << Finding{'missing_page', if chain.len == 0 { 0 } else { chain.last() }, 0}
			break
		}
		if visited[idx] {
			findings << Finding{'cursor_cycle', idx + 1, 0}
			break
		}
		visited[idx] = true
		chain << idx + 1
		p := c.pages[idx]
		if p.total == -1 {
			unknown_totals++
		} else {
			totals[p.total] = true
		}
		if p.revision == '' {
			unknown_revisions++
		} else {
			revisions[p.revision] = true
		}
		for id in p.record_ids {
			count++
			if old := ids[id] {
				findings << Finding{'duplicate_record_id', idx + 1, old + 1}
			} else {
				ids[id] = idx
			}
		}
		if p.next_cursor == '' {
			terminal = true
			break
		}
		cursor = p.next_cursor
	}
	for i, _ in c.pages {
		if !visited[i] { findings << Finding{'unreachable_page', i + 1, 0} }
	}
	mut total := -1
	if totals.len > 1 { findings << Finding{'inconsistent_total', 0, 0} }
	if totals.len == 1 { total = totals.keys()[0] }
	if unknown_totals > 0 { findings << Finding{'unknown_total', 0, 0} }
	if total >= 0 && totals.len == 1 && ids.len != total {
		findings << Finding{'total_mismatch', 0, 0}
	}
	mut rs := 'unknown'
	if revisions.len > 1 {
		rs = 'inconsistent'
		findings << Finding{'inconsistent_revision', 0, 0}
	} else if unknown_revisions > 0 {
		rs = 'unknown'
		findings << Finding{'unknown_revision', 0, 0}
	} else if revisions.len == 1 {
		rs = 'consistent'
	}
	status := if terminal && findings.len == 0 {
		'consistent_capture'
	} else if findings.all(it.code in ['unknown_total', 'unknown_revision']) && terminal {
		'unverified_metadata'
	} else {
		'needs_review'
	}
	return Report{
		status:            status
		chain_pages:       chain
		supplied_pages:    c.pages.len
		reachable_records: count
		unique_records:    ids.len
		declared_total:    total
		revision_state:    rs
		findings:          findings
	}
}
