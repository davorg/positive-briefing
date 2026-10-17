# Positivity Briefing

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

- Perl 5.36 or newer.
- The CPAN runtime and test dependencies listed in `cpanfile`.
- An OpenAI API key and network access to the API.

From the repository root, install the runtime and test dependencies with `cpanm`:

```sh
cpanm --installdeps .
```

Dependencies are declared in `cpanfile`; there is no lockfile. The same install
command can be used in a GitHub Actions job before running `prove -v t`.
The OpenAI client must provide the `createResponse` method.

Set the API key in your shell, then run the generator:

```sh
export OPENAI_API_KEY='your-api-key'
./bin/get-briefing
```

With no arguments, it builds a fresh prompt with three different topic areas
selected at random from twelve areas, including science, language, nature,
repair, cooking, art, community, history, and everyday practical skills. It asks
for a useful fact or technique, a concrete reason for optimism, and an action
that takes under five minutes without buying anything.

The prompt requests short, specific items in British English, varied sentence
openings, and no generic motivational filler or repeated wellness advice. When
`docs/briefing.json` contains a valid briefing, that text is included as reference
material with instructions to choose different subjects, facts, and activities.
Missing or invalid previous content is ignored. Only the last saved briefing is
used, so this encourages variety without keeping a longer history or guaranteeing
unique content every day.

Arguments replace the entire default prompt, including its random topics and
previous-briefing context. They are joined with spaces:

```sh
./bin/get-briefing 'Give me a briefing for a rainy day: something useful, something hopeful, and one tiny action.'
```

The command validates the response against the full JSON schema, then creates
`docs/briefing.json` as a compact UTF-8 JSON array and `docs/feed.atom` as an Atom
feed. Destinations are relative to the script's location, so you can invoke it
from any working directory. Both outputs are prepared and written to temporary
files before either is published. Each destination is replaced atomically;
the two replacements are separate filesystem operations. API, parsing,
validation, or staging failures leave the previous files intact, and temporary
files are cleaned up. Publish both outputs after a successful run.

After a successful update, the same JSON is also printed to standard output.
No shell redirection is needed to update the site. Keep the API key in the
generator's environment; the static site does not need it.

## Atom feed

The production site URL is `https://positivitybriefing.com/`, and the feed URL
is `https://positivitybriefing.com/feed.atom`. Locally, use
<http://127.0.0.1:8000/feed.atom> after starting the preview server. The small
feed icon after “Updated daily” links to it, and the HTML head includes an Atom
autodiscovery link for feed readers.

Each successful generation refreshes the feed with the latest three items as
separate entries, with full text, category titles, UTC update timestamps, and
links to the corresponding items on the page. `XML::Feed` handles Atom output;
text is escaped before being passed to its inline XHTML content handling.
Entry IDs depend on item position, type, and text, so unchanged items retain
their identity across regenerations. The feed retains the current briefing
only; it does not accumulate an archive.

## How it works

```text
Default prompt + previous briefing, or custom prompt
                  + OPENAI_API_KEY
                  |
                  v
          bin/get-briefing --> OpenAI Responses API
                  |
                  v
      validate, then replace file
                  |
                  v
         docs/briefing.json <-- docs/app.js <-- browser
                  |
          JSON also on stdout
```

The generator calls `createResponse` with the hardcoded model `gpt-6-luna`,
reasoning effort `none`, and temperature `0.7`. These settings and the default
prompt-building rules live in `bin/get-briefing`; there are no command-line flags
for the model settings.

It requests strict structured output with an object shaped as
`{"items": [...]}`. It concatenates the response's `output_text` blocks, decodes
the JSON as Perl text, and validates it locally against the same schema sent to
the API. Only a valid response is saved, without the outer object. API failures
produce diagnostics on standard error and terminate the command. Missing output
text or invalid JSON/schema also terminate it; there is no retry loop.

On page load, `app.js` fetches `briefing.json` with `cache: "no-store"`, checks
that it is an array of three items, then renders each item's type and text using
DOM text nodes. Failed requests, invalid JSON, or rendering errors show
“Couldn’t load today’s briefing. Try refreshing.” The page fetches once per load;
there is no polling.

The background rotates through four bundled landscape and sunset photos, with
the selection changing each UTC day on page load. Images are served from
`docs/images/backgrounds/`, with no external image request or API key needed.
The daily image is preloaded before switching the background and its linked
photographer credit. A bundled ocean sunset is the CSS fallback while loading,
if the selected photo fails, or if JavaScript is unavailable. Photo sources and
licensing are recorded in `docs/images/backgrounds/CREDITS.md`.

The page pairs Instrument Serif headlines with DM Sans body text and DM Mono
labels, loaded from Google Fonts with local serif, sans-serif, and monospace
fallbacks. Its layout places the title alongside a paper-style briefing panel
on larger screens and stacks them on mobile. Decorative SVGs are hidden from
screen readers, and entrance animations respect reduced-motion preferences.

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
The generator checks these requirements before replacing the saved file.
The schema permits repeated types and does not enforce their order; the default
prompt supplies the intent to include one of each. The browser preserves the
array's order and does not validate individual fields before rendering.

## Repository layout

| File | Purpose |
| --- | --- |
| `cpanfile` | Perl version requirement and runtime/test dependencies. |
| `bin/get-briefing` | Perl CLI that requests, validates, saves, and prints a new briefing. |
| `lib/PositivityBriefing/Feed.pm` | Builds the Atom feed using `XML::Feed`. |
| `docs/index.html` | Page structure, loading message, and footer. |
| `docs/app.js` | JSON fetching, rendering, error display, and background loading. |
| `docs/style.css` | Responsive editorial layout, typography, and background styling. |
| `docs/images/backgrounds/` | Bundled daily background photos and their credits. |
| `docs/briefing.json` | Saved briefing served to every visitor. |
| `docs/feed.atom` | Atom feed containing the latest three briefing items. |

Despite its name, `docs/` is the website's public directory.

## Publishing and daily updates

Publish the contents of `docs/` to a static web host, preserving the relative
paths between the HTML, JavaScript, CSS, and JSON files. The host does not need
Perl or an API key. The repository does not include deployment configuration.

The page says “Updated daily”, but the repository contains no scheduler or
automation to make that happen. To provide daily briefings, an external job
must run the generator and publish the updated `briefing.json` and `feed.atom`
after a successful run. Configure credentials in that job's environment.
Generating the files locally does not update a hosted copy.

The feed includes generation timestamps, but there is no archive or page
freshness check. All visitors see the same saved briefing until it is replaced.
The generation request includes no search or retrieval tools, and the output
format has no source citations.

## Local checks

These checks do not make an API request:

```sh
perl -c bin/get-briefing
node --check docs/app.js
python3 -m json.tool docs/briefing.json
prove -v t
```

The Perl check requires the CPAN dependencies to be installed. The JSON check
validates JSON syntax, not the full briefing format. The regression tests in
`t/` run the generator with small Perl test doubles for the API response and
check that ASCII, accented characters, curly punctuation, and emoji survive as
valid UTF-8 JSON.
They also check that invalid responses and failed file replacements preserve
existing content and clean up temporary files. Each run uses an isolated copy
of the generator and a temporary `docs/` directory.
They require the Perl dependencies above and do not need an API key.
Feed tests also check Atom metadata, stable IDs, links, Unicode, XML escaping,
and preservation of existing outputs when feed generation fails.
Previewing the page also checks that the static files can be served together.
There is no CI configuration in the repository.
