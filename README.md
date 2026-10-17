# Positive Briefing

A small web page that displays a three-part “sunrise briefing”: something useful,
something hopeful, and one small action to take today. A Perl command generates
the content through OpenAI; a static HTML/CSS/JavaScript site displays the saved
JSON file.

The repository contains a sample briefing, so you can preview the site without
an API key. Generating new content is a separate step.

## Preview the site

From the repository root, run:

```sh
python3 -m http.server 8000 --bind 127.0.0.1 --directory docs
```

Open <http://127.0.0.1:8000/>. Stop the server with Ctrl+C. Use an HTTP server:
opening `docs/index.html` directly with a `file://` URL can prevent the browser
from fetching the JSON file.

No frontend dependencies, package installation, or build step are required.
Python is only used here as a convenient local static server.

## Generate a briefing

You need:

- Perl with support for subroutine signatures (Perl 5.36 or newer recommended).
- The CPAN modules `OpenAPI::Client::OpenAI` and `JSON::MaybeXS`.
- An OpenAI API key and network access to the API.

If you use `cpanm`, install the modules with:

```sh
cpanm OpenAPI::Client::OpenAI JSON::MaybeXS
```

There is no dependency manifest or lockfile. The local environment inspected
while documenting this project had Perl 5.42.3, `OpenAPI::Client::OpenAI` 0.25,
and `JSON::MaybeXS` 1.004008; these are observed versions, not pinned requirements.
The client must provide the `createResponse` method.

Set the API key in your shell, then run the generator:

```sh
export OPENAI_API_KEY='your-api-key'
./bin/get-briefing
```

With no arguments, its prompt is:

> Give me a 3-bullet sunrise briefing: something useful, something hopeful, one tiny action I can do today.

Arguments replace that prompt. They are joined with spaces:

```sh
./bin/get-briefing 'Give me a briefing for a rainy day: something useful, something hopeful, and one tiny action.'
```

The command prints a compact UTF-8 JSON array to standard output. It does not
update the site itself. To replace the site's briefing only after the command
succeeds, run from the repository root:

```sh
./bin/get-briefing > docs/briefing.json.new &&
  mv docs/briefing.json.new docs/briefing.json
```

A failed run leaves the existing `briefing.json` intact and may leave a `.new`
file. Keep the API key in the generator's environment; the static site does not
need it.

## How it works

```text
Default or custom prompt + OPENAI_API_KEY
                  |
                  v
          bin/get-briefing --> OpenAI Responses API
                  |
                  v
            JSON on stdout
                  |
          save/publish separately
                  |
                  v
         docs/briefing.json <-- docs/app.js <-- browser
```

The generator calls `createResponse` with the hardcoded model `gpt-6-luna`,
reasoning effort `none`, and temperature `0.7`. These settings and the default
prompt live in `bin/get-briefing`; there are no command-line flags for them.

It requests strict structured output with an object shaped as
`{"items": [...]}`. It concatenates the response's `output_text` blocks, decodes
the JSON, checks that `items` is an array, and prints that array without the
outer object. API failures produce diagnostics on standard error and terminate
the command. Missing output text or a missing `items` array also terminate it;
there is no retry loop.

On page load, `app.js` fetches `briefing.json` with `cache: "no-store"`, checks
that it is an array of three items, then renders each item's type and text using
DOM text nodes. Failed requests, invalid JSON, or rendering errors show
“Couldn’t load today’s briefing. Try refreshing.” The page fetches once per load;
there is no polling.

The browser also attempts to preload a sunrise image from
`https://source.unsplash.com/1920x1080/?sunrise&sig=YYYYMMDD`, using the current
UTC date. A successful load sets the background image. A failed load logs a
console warning and leaves the dark CSS background in place.

## Briefing format

The file consumed by the page is an array, for example:

```json
[
  { "type": "useful", "text": "Write down your top priority for today." },
  { "type": "hopeful", "text": "Small steps can add up over time." },
  { "type": "action", "text": "Spend two minutes starting that priority." }
]
```

The API schema requires exactly three objects, each with only `type` and `text`.
`type` must be `useful`, `hopeful`, or `action`, and `text` must be a string.
The schema permits repeated types and does not enforce their order; the default
prompt supplies the intent to include one of each. The browser preserves the
array's order and does not validate individual fields before rendering.

## Repository layout

| File | Purpose |
| --- | --- |
| `bin/get-briefing` | Perl CLI that requests and prints a new briefing. |
| `docs/index.html` | Page structure, loading message, and footer. |
| `docs/app.js` | JSON fetching, rendering, error display, and background loading. |
| `docs/style.css` | Responsive card layout and background styling. |
| `docs/briefing.json` | Saved briefing served to every visitor. |

Despite its name, `docs/` is the website's public directory.

## Publishing and daily updates

Publish the contents of `docs/` to a static web host, preserving the relative
paths between the HTML, JavaScript, CSS, and JSON files. The host does not need
Perl or an API key. The repository does not include deployment configuration.

The page says “Updated daily” and “Briefing generated daily”, but the repository
contains no scheduler or automation to make that happen. To provide daily
briefings, an external job must run the generator, replace `briefing.json` on
success, and publish the updated file. Configure credentials in that job's
environment. Generating the JSON locally does not update a hosted copy.

There is no generation timestamp, archive, or freshness check. All visitors see
the same saved briefing until it is replaced. The generation request includes
no search or retrieval tools, and the output format has no source citations.

## Local checks

These checks do not make an API request:

```sh
perl -c bin/get-briefing
node --check docs/app.js
python3 -m json.tool docs/briefing.json
```

The Perl check requires the CPAN dependencies to be installed. The JSON check
validates JSON syntax, not the full briefing format. Previewing the page also
checks that the static files can be served together. There is no automated test
suite or CI configuration in the repository.
