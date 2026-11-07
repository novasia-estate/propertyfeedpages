module main

import os
import propertyfeedpages

fn main() {
	if os.args.len !in [2, 3, 4] {
		eprintln('Usage: feedpages capture.json [--html] [--batch]')
		exit(2)
	}
	mut html := false
	mut batch := false
	for flag in os.args[2..] {
		if flag == '--html' && !html {
			html = true
		} else if flag == '--batch' && !batch {
			batch = true
		} else {
			eprintln('unknown or duplicate option')
			exit(2)
		}
	}
	if os.file_size(os.args[1]) > 16777216 {
		eprintln('input exceeds 16 MiB')
		exit(2)
	}
	text := os.read_file(os.args[1]) or {
		eprintln('could not read capture')
		exit(2)
	}
	if batch {
		r := propertyfeedpages.audit_json_batch(text) or {
			eprintln(err.msg())
			exit(2)
		}
		println(if html {
			propertyfeedpages.batch_report_html(r)
		} else {
			propertyfeedpages.batch_report_json(r)
		})
		if r.status != 'consistent_batch' { exit(1) }
		return
	}
	capture := propertyfeedpages.decode_capture(text) or {
		eprintln(err.msg())
		exit(2)
	}
	r := propertyfeedpages.audit(capture) or {
		eprintln(err.msg())
		exit(2)
	}
	if html {
		println(propertyfeedpages.report_html(r))
	} else {
		println(propertyfeedpages.report_json(r))
	}
	if r.status != 'consistent_capture' { exit(1) }
}
