module propertyfeedpages

import json
import x.json2

pub struct BatchCapture {
pub:
	schema_version int = 1
	captures       []Capture
}

pub struct BatchItem {
pub:
	capture_index int
	status        string
	error_code    string
	report        ?Report
}

pub struct BatchReport {
pub:
	schema_version             int = 1
	status                     string
	consistent_count           int
	review_count               int
	invalid_count              int
	sum_capture_unique_records int
	items                      []BatchItem
	limitation                 string = 'Captures are independent. Counts sum within-capture observations, not distinct properties across captures or a complete upstream inventory.'
}

pub fn audit_batch(captures []Capture) !BatchReport {
	if captures.len < 1 || captures.len > 100 { return error('batch requires 1..100 captures') }
	return audit_json_batch(json.encode(BatchCapture{ captures: captures }))
}

// One invalid capture cannot hide the independently valid results next to it.
pub fn audit_json_batch(text string) !BatchReport {
	if text.len > 16777216 { return error('batch input exceeds 16 MiB') }
	root := json2.decode[map[string]json2.Any](text) or { return error('batch must be an object') }
	if root.len != 2 || 'schema_version' !in root || 'captures' !in root {
		return error('batch requires exactly schema_version and captures')
	}
	sv := root['schema_version']!
	if !number(sv) || sv.f64() != 1 { return error('unsupported batch schema_version') }
	raw := root['captures']!
	if raw !is []json2.Any { return error('captures must be an array') }
	captures := raw.as_array()
	if captures.len < 1 || captures.len > 100 { return error('batch requires 1..100 captures') }
	mut items := []BatchItem{}
	mut consistent := 0
	mut review := 0
	mut invalid := 0
	mut sum_unique := 0
	mut pages := 0
	mut ids := 0
	for i, item in captures {
		c := decode_capture(json2.encode(item)) or {
			invalid++
			items << BatchItem{
				capture_index: i + 1
				status:        'invalid_capture'
				error_code:    'invalid_capture'
			}
			continue
		}
		pages += c.pages.len
		for page in c.pages {
			ids += page.record_ids.len
		}
		if pages > 20000 || ids > 200000 {
			return error('batch aggregate page/record limit exceeded')
		}
		r := audit(c) or {
			invalid++
			items << BatchItem{
				capture_index: i + 1
				status:        'invalid_capture'
				error_code:    'invalid_capture'
			}
			continue
		}
		if r.status == 'consistent_capture' {
			consistent++
		} else {
			review++
		}
		sum_unique += r.unique_records
		items << BatchItem{
			capture_index: i + 1
			status:        r.status
			report:        r
		}
	}
	return BatchReport{
		status:                     if review == 0 && invalid == 0 {
			'consistent_batch'
		} else {
			'needs_review'
		}
		consistent_count:           consistent
		review_count:               review
		invalid_count:              invalid
		sum_capture_unique_records: sum_unique
		items:                      items
	}
}

pub fn batch_report_json(r BatchReport) string {
	return json.encode_pretty(r)
}

pub fn batch_report_html(r BatchReport) string {
	mut rows := ''
	mut findings := ''
	for item in r.items {
		rows += '<tr><td>${item.capture_index}</td><td>${escape(item.status)}</td><td>${escape(item.error_code)}</td></tr>'
		if report := item.report {
			for finding in report.findings {
				findings += '<tr><td>${item.capture_index}</td><td>${escape(finding.code)}</td><td>${finding.page}</td><td>${finding.related_page}</td></tr>'
			}
		}
	}
	return '<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>Property Feed Pages batch</title><style>body{max-width:1000px;margin:3rem auto;padding:1rem;font:17px system-ui;color:#213047}table{border-collapse:collapse;width:100%}td,th{border:1px solid #ccd7e2;padding:.5rem;text-align:left}</style></head><body><h1>Property Feed Pages batch</h1><p>Status: ${escape(r.status)}. Consistent: ${r.consistent_count}; review: ${r.review_count}; invalid: ${r.invalid_count}. Sum of per-capture unique records: ${r.sum_capture_unique_records}.</p><table><thead><tr><th>Capture index</th><th>Status</th><th>Error</th></tr></thead><tbody>${rows}</tbody></table><h2>Findings</h2><table><thead><tr><th>Capture index</th><th>Code</th><th>Page</th><th>Related page</th></tr></thead><tbody>${findings}</tbody></table><p>${escape(r.limitation)}</p><p>Open-source tooling by <a href="https://novasia.estate/">NovAsia Estate</a>.</p></body></html>'
}
