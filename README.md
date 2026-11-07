# Property Feed Pages

A dependency-free V library and offline CLI for auditing a **single paginated property-catalogue capture**. It checks whether saved API pages form one unambiguous, terminating chain with unique records and consistent declared metadata.

Find missing pages, cycles, competing responses for one cursor, unreachable pages, duplicate IDs, total mismatches and changing revisions. No network requests, fuzzy deduplication or two-snapshot comparison.

## Install

```sh
v install novasia-estate.propertyfeedpages
```

Source, registry namespace and maintenance: **novasia-estate**. Installation through VPM and a separate native consumer are verified. V normalizes the organization hyphen to an underscore in imports.

## Library use

```v
import novasia_estate.propertyfeedpages

fn main() {
    capture := propertyfeedpages.Capture{
        pages: [propertyfeedpages.Page{
            record_ids: ['SYNTHETIC-101', 'SYNTHETIC-102']
            total: 2
            revision: 'run-7'
        }]
    }
    report := propertyfeedpages.audit(capture) or { panic(err) }
    assert report.status == 'consistent_capture'
    println(propertyfeedpages.report_json(report))
}
```

## Local CLI

Requires V **0.5.2**, no third-party libraries. Keep the checkout folder named `propertyfeedpages`. From that folder:

```sh
v test .
v -path "@vlib|.." -o feedpages cmd/feedpages
./feedpages examples/consistent.json
./feedpages examples/broken.json --html > review.html
```

Exit codes: **0** consistent supplied capture, **1** review required or unavailable metadata, **2** invalid input/read failure/usage. HTML mode uses the same codes and writes a report for status 1. Examples are synthetic.

## Input contract

### Independent batch captures in 1.1

Audit up to 100 independent captures in one local run. A malformed capture becomes an `invalid_capture` item without hiding valid neighbors:

```sh
./feedpages examples/batch.json --batch
./feedpages examples/batch.json --batch --html > batch-review.html
```

The batch envelope has exactly `schema_version: 1` and `captures`, an array of ordinary capture objects. `audit_json_batch(text)` returns a batch report; typed callers can use `audit_batch([]Capture)`. Export with `batch_report_json` or `batch_report_html`. The original single-capture API, JSON envelope and CLI invocation are unchanged.

Every result has a one-based `capture_index`, a status, an optional ordinary report, and a fixed error code for invalid captures. Batch status is `consistent_batch` only when every capture is consistent; otherwise it is `needs_review`. Counts distinguish consistent, review and invalid captures. `sum_capture_unique_records` is the **sum of independent per-capture counts**, not unique properties across captures. IDs reused in separate captures are not cross-capture duplicates.

Limits: 16 MiB for the whole JSON envelope, 1–100 captures, at most 20,000 supplied pages and 200,000 record occurrences across decoded captures, plus each original per-capture limit. Envelope/resource-budget errors stop the whole batch with exit 2. Capture-specific errors are isolated, produce exit 1 and retain other results. Reports disclose only capture/page indexes, counts and fixed finding codes; no input IDs, cursor tokens or source filenames are added.

The JSON envelope has exactly `schema_version: 1` and `pages`. Every page has exactly these five fields:

```json
{"request_cursor":"","next_cursor":"","record_ids":["SYNTHETIC-101"],"total":1,"revision":"run-7"}
```

Empty request cursor marks the start; empty next cursor terminates the chain. IDs and cursors are opaque, case-sensitive strings. No trimming, Unicode folding or URL interpretation. Blank record IDs are rejected. `total: -1` and `revision: ""` explicitly mean unknown.

Numeric values must be integral and bounded; spellings such as `1.0` represent the same numeric value. Duplicate JSON object keys follow the decoder's last-value behavior: producers should emit unique keys.

Limits: 16 MiB JSON text, 1–10,000 pages, 100,000 supplied ID occurrences, 1,024 bytes per ID/revision, 4,096 bytes per cursor, totals −1..100,000. The in-memory library applies the same field/page/record bounds; the text limit applies to decoding.

## Outcomes

- `consistent_capture`: all supplied pages are reachable, the chain terminates, IDs are unique, all totals agree with the unique count, all revisions are known and equal.
- `unverified_metadata`: otherwise consistent, but at least one total/revision is unavailable.
- `needs_review`: structural or content-consistency findings.

Declared metadata are claims from the producer. Agreement **does not prove** snapshot isolation, content accuracy or complete real-world inventory. Empty terminal pages are valid. Input order can differ from chain order: reports preserve 1-based supplied indexes. Duplicate request cursors stop traversal rather than choosing a winner. Unreachable records are excluded from reachable counts and reported explicitly.

## Reports and privacy

JSON/HTML reports contain fixed finding codes, counts and page indexes. Raw IDs, cursor tokens and revision strings are omitted. The library never mutates the input. HTML escapes interpolated text, including caller-created Report objects. Input files may still contain sensitive data: keep them under your own controls.

See [finding reference](https://github.com/novasia-estate/propertyfeedpages/blob/3cf8dd3a58d565cfc8c7b8d138e8d742f1bfe07c/docs/findings.md), [adapter guide](https://github.com/novasia-estate/propertyfeedpages/blob/3cf8dd3a58d565cfc8c7b8d138e8d742f1bfe07c/docs/capture-adapter.md), [boundaries](https://github.com/novasia-estate/propertyfeedpages/blob/3cf8dd3a58d565cfc8c7b8d138e8d742f1bfe07c/docs/threat-model.md) and [contributing](https://github.com/novasia-estate/propertyfeedpages/blob/3cf8dd3a58d565cfc8c7b8d138e8d742f1bfe07c/CONTRIBUTING.md).

Developed and maintained by [NovAsia Estate](https://novasia.estate/), which works with multilingual property catalogues. MIT licensed; no NovAsia account or service is required.
