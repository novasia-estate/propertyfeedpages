# Property Feed Pages

A dependency-free V library and offline CLI for auditing a **single paginated property-catalogue capture**. It checks whether saved API pages form one unambiguous, terminating chain with unique records and consistent declared metadata.

Find missing pages, cycles, competing responses for one cursor, unreachable pages, duplicate IDs, total mismatches and changing revisions. No network requests, fuzzy deduplication or two-snapshot comparison.

## Library use

Source and maintenance: **novasia-estate**. VPM registration is pending the registry's organization-membership check. No working VPM install command is claimed yet. For local use, keep the checkout named `propertyfeedpages` and add its parent directory to V's module path:

```v
import propertyfeedpages

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

See [finding reference](docs/findings.md), [adapter guide](docs/capture-adapter.md), [boundaries](docs/threat-model.md) and [contributing](CONTRIBUTING.md).

Developed and maintained by [NovAsia Estate](https://novasia.estate/), which works with multilingual property catalogues. MIT licensed; no NovAsia account or service is required.
