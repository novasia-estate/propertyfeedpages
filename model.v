module propertyfeedpages

// Empty request_cursor identifies the first page; empty next_cursor is terminal.
pub struct Page {
pub:
	request_cursor string
	next_cursor    string
	record_ids     []string
	total          int = -1
	revision       string
}

pub struct Capture {
pub:
	schema_version int = 1
	pages          []Page
}

pub struct Finding {
pub:
	code         string
	page         int // 1-based supplied page index; zero means capture-wide
	related_page int
}

pub struct Report {
pub:
	schema_version    int = 1
	status            string
	chain_pages       []int
	supplied_pages    int
	reachable_records int
	unique_records    int
	declared_total    int = -1
	revision_state    string
	findings          []Finding
	limitation        string = 'Checks only the supplied capture. Does not prove upstream inventory, record truth, or server snapshot isolation.'
}
