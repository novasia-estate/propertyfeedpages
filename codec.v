module propertyfeedpages

import json
import x.json2

// Strict envelope rejects misspelled keys, nulls, fractional numeric values and silent defaults.
pub fn decode_capture(text string) !Capture {
	if text.len > 16777216 { return error('input exceeds 16 MiB') }
	root := json2.decode[map[string]json2.Any](text) or {
		return error('capture must be a JSON object')
	}
	if root.len != 2 || 'schema_version' !in root || 'pages' !in root {
		return error('capture requires exactly schema_version and pages')
	}
	sv := root['schema_version'] or { return error('missing schema_version') }
	if !number(sv) || sv.f64() != 1 { return error('schema_version must be an integer') }
	if sv.f64() != 1 { return error('unsupported schema_version') }
	raw := root['pages'] or { return error('missing pages') }
	if raw !is []json2.Any { return error('pages must be an array') }
	mut pages := []Page{}
	for item in raw.as_array() {
		if item !is map[string]json2.Any { return error('each page must be an object') }
		fields := item.as_map()
		if fields.len != 5 {
			return error('page requires exactly request_cursor, next_cursor, record_ids, total, revision')
		}
		for key in ['request_cursor', 'next_cursor', 'revision'] {
			v := fields[key] or { return error('missing page string field') }
			if v !is string { return error('page cursor/revision must be strings') }
		}
		t := fields['total'] or { return error('missing total') }
		if !number(t) || t.f64() != f64(t.i64()) { return error('total must be an integer') }
		if t.f64() < -1 || t.f64() > 100000 {
			return error('total out of supported range -1..100000')
		}
		a := fields['record_ids'] or { return error('missing record_ids') }
		if a !is []json2.Any { return error('record_ids must be an array') }
		mut ids := []string{}
		for id in a.as_array() {
			if id !is string {
				return error('record_ids must contain strings')
			} else {
				ids << id
			}
		}
		pages << Page{
			request_cursor: fields['request_cursor']!.str()
			next_cursor:    fields['next_cursor']!.str()
			record_ids:     ids
			total:          t.int()
			revision:       fields['revision']!.str()
		}
	}
	return Capture{
		pages: pages
	}
}

pub fn report_json(r Report) string {
	return json.encode_pretty(r)
}

// Reports intentionally contain fixed vocabulary and page indexes only.
pub fn report_html(r Report) string {
	mut rows := ''
	for f in r.findings {
		rows += '<tr><td>${escape(f.code)}</td><td>${f.page}</td><td>${f.related_page}</td></tr>'
	}
	return '<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>Property Feed Pages audit</title><style>body{max-width:850px;margin:3rem auto;padding:1rem;font:17px system-ui;color:#17263b}table{border-collapse:collapse;width:100%}td,th{border:1px solid #ccd7e2;padding:.6rem;text-align:left}code{overflow-wrap:anywhere}</style></head><body><h1>Property Feed Pages</h1><p>Status: <strong>${escape(r.status)}</strong></p><p>Reachable pages: ${r.chain_pages.len}/${r.supplied_pages}; records: ${r.reachable_records}; unique: ${r.unique_records}; declared total: ${r.declared_total} (-1 = unknown).</p><p>Revision metadata: ${escape(r.revision_state)}.</p><table><thead><tr><th>Finding</th><th>Page</th><th>Related page</th></tr></thead><tbody>${rows}</tbody></table><p>${escape(r.limitation)}</p><p>Open-source tooling by <a href="https://novasia.estate/">NovAsia Estate</a>.</p></body></html>'
}

fn escape(s string) string {
	return s.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;').replace('"', '&quot;').replace("'",
		'&#39;')
}

fn number(v json2.Any) bool {
	return v is f64 || v is f32 || v is int || v is i64 || v is u64 || v is i32 || v is i16
		|| v is i8 || v is u32 || v is u16 || v is u8
}
