module main

import os
import propertyfeedpages

fn main() {
	if os.args.len !in [2, 3] {
		eprintln('Usage: feedpages capture.json [--html]')
		exit(2)
	}
	if os.args.len == 3 && os.args[2] != '--html' {
		eprintln('unknown option')
		exit(2)
	}
	if os.file_size(os.args[1]) > 16777216 {
		eprintln('input exceeds 16 MiB')
		exit(2)
	}
	text := os.read_file(os.args[1]) or {
		eprintln('could not read capture')
		exit(2)
	}
	capture := propertyfeedpages.decode_capture(text) or {
		eprintln(err.msg())
		exit(2)
	}
	r := propertyfeedpages.audit(capture) or {
		eprintln(err.msg())
		exit(2)
	}
	if os.args.len == 3 {
		println(propertyfeedpages.report_html(r))
	} else {
		println(propertyfeedpages.report_json(r))
	}
	if r.status != 'consistent_capture' { exit(1) }
}
