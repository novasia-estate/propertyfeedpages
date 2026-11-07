module propertyfeedpages

import json

fn one() Capture {
	return Capture{
		pages: [Page{ record_ids: ['same-id'], total: 1, revision: 'r' }]
	}
}

fn test_independent_consistent_captures() {
	r := audit_batch([one(), one()])!
	assert r.status == 'consistent_batch'
	assert r.consistent_count == 2
	assert r.sum_capture_unique_records == 2
}

fn test_invalid_capture_does_not_hide_valid_neighbor() {
	r := audit_json_batch('{"schema_version":1,"captures":[null,' + json.encode(one()) + ']}')!
	assert r.invalid_count == 1
	assert r.consistent_count == 1
	assert r.items[1].capture_index == 2
}

fn test_typed_invalid_capture_is_isolated() {
	r := audit_batch([Capture{}, one()])!
	assert r.invalid_count == 1
	assert r.items[0].report == none
}

fn test_unknown_metadata_counts_as_review() {
	r := audit_batch([Capture{ pages: [Page{}] }])!
	assert r.review_count == 1
	assert r.status == 'needs_review'
}

fn test_mixed_structural_findings_keep_capture_index() {
	r := audit_batch([one(), Capture{
		pages: [Page{ next_cursor: 'missing' }]
	}])!
	assert r.items[1].capture_index == 2
	assert (r.items[1].report or { panic('missing report') }).findings.any(it.code == 'missing_page')
}

fn test_batch_rejects_zero_captures() {
	if _ := audit_batch([]Capture{}) { assert false
	 }
}

fn test_batch_capture_count_bound() {
	if _ := audit_batch([]Capture{len: 101, init: one()}) { assert false
	 }
}

fn test_batch_envelope_rejects_wrong_shapes() {
	for s in ['null', '[]', '{}', '{"schema_version":2,"captures":[]}',
		'{"schema_version":1,"captures":null}', '{"schema_version":1,"captures":[],"extra":1}'] {
		if _ := audit_json_batch(s) { assert false, s
		 }
	}
}

fn test_batch_privacy() {
	c := Capture{
		pages: [
			Page{
				record_ids:  ['PRIVATE-ID', 'PRIVATE-ID']
				next_cursor: 'PRIVATE-CURSOR'
				revision:    'PRIVATE-REV'
			},
		]
	}
	r := audit_batch([c])!
	assert !(batch_report_json(r) + batch_report_html(r)).contains('PRIVATE')
}

fn test_batch_html_escaping() {
	r := BatchReport{
		status: '<script>'
		items:  [BatchItem{ capture_index: 1, status: '<img>', error_code: '"<&' }]
	}
	html := batch_report_html(r)
	assert !html.contains('<script>')
	assert html.contains('&lt;img&gt;')
	assert html.contains('&quot;&lt;&amp;')
}

fn test_batch_aggregate_pages_bound() {
	c := Capture{
		pages: []Page{len: 10000, init: Page{}}
	}
	if _ := audit_batch([c, c, c]) { assert false
	 }
}

fn test_batch_aggregate_ids_bound() {
	c := Capture{
		pages: [Page{ record_ids: []string{len: 100000, init: 'x'} }]
	}
	if _ := audit_batch([c, c, c]) { assert false
	 }
}

fn test_batch_deterministic_and_no_mutation() {
	captures := [one(), one()]
	before := json.encode(captures)
	assert audit_batch(captures)! == audit_batch(captures)!
	assert json.encode(captures) == before
}
