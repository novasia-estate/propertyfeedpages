module propertyfeedpages

import json

fn base() Capture {
	return Capture{
		pages: [Page{ next_cursor: 'B', record_ids: ['a', 'b'], total: 3, revision: 'r' },
			Page{ request_cursor: 'B', record_ids: ['c'], total: 3, revision: 'r' }]
	}
}

fn has(r Report, code string) bool {
	return r.findings.any(it.code == code)
}

fn test_consistent_chain() {
	r := audit(base())!
	assert r.status == 'consistent_capture'
	assert r.chain_pages == [1, 2]
	assert r.unique_records == 3
}

fn test_empty_inventory() {
	assert audit(Capture{
		pages: [Page{ total: 0, revision: 'r' }]
	})!.status == 'consistent_capture'
}

fn test_unknown_metadata() {
	r := audit(Capture{ pages: [Page{}] })!
	assert r.status == 'unverified_metadata'
	assert has(r, 'unknown_total')
	assert has(r, 'unknown_revision')
}

fn test_library_rejects_unsupported_schema() {
	if _ := audit(Capture{ schema_version: 2, pages: [Page{}] }) { assert false
	 }
}

fn test_library_rejects_empty_capture() {
	if _ := audit(Capture{}) { assert false
	 }
}

fn test_library_rejects_negative_total() {
	if _ := audit(Capture{
		pages: [Page{ total: -2 }]
	})
	{ assert false
	 }
}

fn test_library_rejects_huge_total() {
	if _ := audit(Capture{
		pages: [Page{ total: 100001 }]
	})
	{ assert false
	 }
}

fn test_library_rejects_blank_id() {
	if _ := audit(Capture{
		pages: [Page{ record_ids: ['  '] }]
	})
	{ assert false
	 }
}

fn test_library_rejects_long_id() {
	if _ := audit(Capture{
		pages: [Page{ record_ids: ['x'.repeat(1025)] }]
	})
	{ assert false
	 }
}

fn test_library_rejects_long_cursor() {
	if _ := audit(Capture{
		pages: [Page{ next_cursor: 'x'.repeat(4097) }]
	})
	{ assert false
	 }
}

fn test_missing_start() {
	r := audit(Capture{
		pages: [Page{ request_cursor: 'B' }]
	})!
	assert has(r, 'missing_page')
	assert has(r, 'unreachable_page')
}

fn test_missing_next() {
	r := audit(Capture{
		pages: [Page{ next_cursor: 'B' }]
	})!
	assert has(r, 'missing_page')
}

fn test_cycle() {
	r := audit(Capture{
		pages: [Page{ next_cursor: 'B' }, Page{ request_cursor: 'B', next_cursor: 'B' }]
	})!
	assert has(r, 'cursor_cycle')
	assert r.chain_pages == [1, 2]
}

fn test_duplicate_cursor_never_chooses_winner() {
	r := audit(Capture{ pages: [Page{}, Page{}] })!
	assert has(r, 'duplicate_request_cursor')
	assert r.chain_pages.len == 0
}

fn test_duplicate_followup_never_chooses_winner() {
	r := audit(Capture{
		pages: [Page{ next_cursor: 'B' }, Page{ request_cursor: 'B' },
			Page{ request_cursor: 'B' }]
	})!
	assert r.chain_pages == [1]
	assert r.status == 'needs_review'
}

fn test_unreachable_page() {
	r := audit(Capture{
		pages: [Page{ total: 0, revision: 'r' }, Page{ request_cursor: 'unused' }]
	})!
	assert has(r, 'unreachable_page')
	assert r.supplied_pages == 2
}

fn test_duplicate_in_page() {
	r := audit(Capture{
		pages: [Page{ record_ids: ['a', 'a'], total: 1, revision: 'r' }]
	})!
	assert has(r, 'duplicate_record_id')
	assert r.unique_records == 1
	assert r.reachable_records == 2
}

fn test_duplicate_across_pages() {
	r := audit(Capture{
		pages: [Page{ next_cursor: 'B', record_ids: ['a'] }, Page{ request_cursor: 'B', record_ids: [
			'a'] }]
	})!
	assert has(r, 'duplicate_record_id')
	assert r.findings.any(it.related_page == 1)
}

fn test_total_mismatch() {
	r := audit(Capture{
		pages: [Page{ total: 1, revision: 'r' }]
	})!
	assert has(r, 'total_mismatch')
}

fn test_total_inconsistent() {
	r := audit(Capture{
		pages: [Page{ next_cursor: 'B', total: 0 }, Page{ request_cursor: 'B', total: 1 }]
	})!
	assert has(r, 'inconsistent_total')
	assert r.declared_total == -1
}

fn test_revision_inconsistent() {
	r := audit(Capture{
		pages: [Page{ next_cursor: 'B', revision: 'one' }, Page{
			request_cursor: 'B'
			revision:       'two'
		}]
	})!
	assert r.revision_state == 'inconsistent'
}

fn test_mixed_unknown_total() {
	r := audit(Capture{
		pages: [Page{ next_cursor: 'B', total: 0, revision: 'r' },
			Page{ request_cursor: 'B', revision: 'r' }]
	})!
	assert r.status == 'unverified_metadata'
}

fn test_mixed_unknown_revision() {
	r := audit(Capture{
		pages: [Page{ next_cursor: 'B', total: 0, revision: 'r' },
			Page{ request_cursor: 'B', total: 0 }]
	})!
	assert has(r, 'unknown_revision')
}

fn test_unordered_pages_preserves_supplied_index() {
	b := base()
	r := audit(Capture{ pages: [b.pages[1], b.pages[0]] })!
	assert r.chain_pages == [2, 1]
	assert r.status == 'consistent_capture'
}

fn test_exact_unicode_ids() {
	r := audit(Capture{
		pages: [
			Page{
				record_ids: ['บ้าน', 'Дом', 'дом']
				total:      3
				revision:   'r'
			},
		]
	})!
	assert r.unique_records == 3
}

fn test_cursor_is_opaque() {
	r := audit(Capture{
		pages: [Page{ next_cursor: ' B ' }, Page{ request_cursor: 'B' }]
	})!
	assert has(r, 'missing_page')
}

fn test_privacy_report() {
	r := audit(Capture{
		pages: [
			Page{
				record_ids:  ['SECRET-ID', 'SECRET-ID']
				revision:    'SECRET-REV'
				next_cursor: 'SECRET-CURSOR'
			},
		]
	})!
	s := report_json(r) + report_html(r)
	assert !s.contains('SECRET')
}

fn test_html_escaping_even_for_external_report() {
	s := report_html(Report{ status: '<script>alert(1)</script>', limitation: '"<&' })
	assert !s.contains('<script>')
	assert s.contains('&lt;script&gt;')
	assert s.contains('&quot;&lt;&amp;')
}

fn test_json_report_roundtrip() {
	r := audit(base())!
	assert json.decode(Report, report_json(r))! == r
}

fn test_decode_valid() {
	b := base()
	assert decode_capture(json.encode(b))! == b
}

fn test_decode_rejects_invalid_envelopes() {
	for s in ['null', '[]', '{}', '{"schema_version":1,"pages":null}',
		'{"schema_version":1.5,"pages":[]}', '{"schema_version":2,"pages":[]}',
		'{"schema_version":1,"pages":[],"extra":1}'] {
		if _ := decode_capture(s) { assert false, s
		 }
	}
}

fn test_decode_rejects_bad_pages() {
	for s in ['null', '{}',
		'{"request_cursor":null,"next_cursor":"","record_ids":[],"total":0,"revision":""}',
		'{"request_cursor":"","next_cursor":"","record_ids":[2],"total":0,"revision":""}',
		'{"request_cursor":"","next_cursor":"","record_ids":[],"total":0.5,"revision":""}',
		'{"request_cursor":"","next_cursor":"","record_ids":[],"total":100001,"revision":""}'] {
		if _ := decode_capture('{"schema_version":1,"pages":[' + s + ']}') { assert false, s
		 }
	}
}

fn test_determinism_no_mutation() {
	b := base()
	before := json.encode(b)
	r := audit(b)!
	assert audit(b)! == r
	assert json.encode(b) == before
}
