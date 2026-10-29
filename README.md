# mcknight.io

The source of [mcknight.io](https://mcknight.io): a [Jekyll](https://jekyllrb.com)
site built to `_site/`, served from an S3 bucket behind a CloudFront
distribution.

Publishing is a person running `make` on a workstation, with one exception:
`.github/workflows/nightly-refresh.yml` keeps the projects page current by
itself (see [Refresh the versions and commit activity on the projects page](#runbooks)).

```
make init                  # once per machine
make build                 # render the main site into _site/
make serve                 # read it at localhost:4000
```

This repo holds **two** sites: mcknight.io and travel.mcknight.io. Most actions
take the site as a word of its own, and naming none means `home`:

```
make build travel          # just the subdomain
make serve home travel     # both at once, on ports 4000 and 4500
make deploy travel         # upload just the subdomain
```

make has no arguments, only goals, so `home` and `travel` are real targets that
do nothing by themselves; each action reads the goal list to see which sites
were named. `make travel` on its own says so rather than failing silently.

`make` on its own lists every target with a one-line summary, and
`make help-<target>` prints the long explanation of one — `make help-deploy`,
`make help-bust-cache`. Those live in the `Makefile` beside the recipes they
describe, so they cannot fall out of step with them. This file covers what a
target list has no room for.

## How publishing works

Three steps, and **none of them implies another**:

1. **`make build [site]`** renders the sources into that site's output directory.
2. **`make deploy [site]`** syncs it to S3 and records the commit it uploaded.
3. **`make bust-cache [site] PATHS=…`** invalidates CloudFront, or visitors keep
   the old page.

`deploy` uploads whatever is already sitting in the output directory, so
deploying without building first ships the *previous* build. It refuses to run from a dirty
working tree, because the commit hash it records could not otherwise describe
what was uploaded.

### What is live

Each site has its own stamp — `DEPLOYED` for the main site, `travel/DEPLOYED`
for the subdomain. `deploy` writes it, uploads it with the site, and commits it:

```
$ curl -s https://mcknight.io/DEPLOYED
0fb51650e48a312926b2ab7a456501d4bb3cf2e7
2026-08-13T11:49:13Z
```

Line 1 is the deployed commit, line 2 the UTC deploy time, so `head -1` is the
hash on its own. It names the commit just *before* the one that records it — a
file holding a hash cannot be inside the commit it names.

### Cache keys are not URLs

A directory URL and its index object are cached separately: `/blog/` is **not**
`/blog/index.html`. Busting a page usually means busting both. `PATHS` is a
space-separated list where every entry begins with `/`; commas separate nothing,
so a comma-joined string is one path that matches no object and invalidates
nothing while reporting success.

## Runbooks

**Publish a post.** `new-post.sh` writes into `blog/_drafts/`, which Jekyll does
not build. Moving it into `blog/_posts/` is what publishes it.

```
scripts/new-post.sh "Title Of The Post"
$EDITOR blog/_drafts/$(date +%F)-title-of-the-post.md
git mv blog/_drafts/2026-08-10-title-of-the-post.md blog/_posts/
make build
git add -A && git commit -m "add a post"
make deploy
make bust-cache PATHS="/ /index.html /blog/ /blog/index.html /blog/2026/08/10/title-of-the-post.html"
```

The date in the filename sets the post's URL, so rename it if the draft has been
sitting a while. Five cache keys for one post: the home page lists the three most
recent, the blog index lists them all, each reachable in two forms, plus the post
itself. Add `/feed.xml` if you want subscribers to see it promptly.

To preview a draft before moving it, build with drafts included:

```
env -u GEM_HOME -u GEM_PATH rbenv exec bundle exec jekyll build --drafts --destination _site
```

(`env -u GEM_HOME` for the reason given in the `Makefile`: tmuxinator leaves its
own `GEM_HOME` in the tmux server environment, and every pane inherits it.)

**Refresh the versions and commit activity on the projects page.**

```
make releases
git add _data/releases.yml && git commit -m "refresh release data"
make build && make deploy
make bust-cache PATHS="/projects/ /projects/index.html"
```

`.github/workflows/nightly-refresh.yml` does this on GitHub every night in four
large population centers (about 03:00 in US East, Central Europe, New Delhi and
Tokyo), and at once when a devtool releases or merges: the shared CI and
release workflows in armcknight/workflows send it a `release-published`
dispatch. It deploys only if `releases.yml` or `activity.yml` changed, and
commits only `releases.yml`. To start one by hand:

```
gh api repos/armcknight/mcknight.io/dispatches -f event_type=release-published
```

Runs queue one at a time, and a newer dispatch replaces one that is still
waiting, so a burst of merges makes one or two deploys. From the Actions tab
the run is a dry run by default: it prints the diff and stops. It needs the
`RELEASES_TOKEN` and `AWS_DEPLOY_ROLE_ARN` secrets; the comment at the top of
the workflow says what each must allow.

`activity.yml` is ignored by git, because its windows end today and so it
changes nearly every day. The workflow keeps its copy, with
`.cache/commit-stats.json`, in the Actions cache, and compares each run's
result with it. On a workstation, `make build home` makes the file when it is
missing (`gh` must be signed in), but leaves an existing one as it is. A
deploy from a workstation therefore shows that machine's activity until the
next run of the workflow; run `make releases` first to deploy current numbers.

**Change the resume.** `resume/` is a submodule of
[armcknight/resume](https://github.com/armcknight/resume), a private repo, so
the resume is changed and committed there. Nothing a visitor sees changes
until the PDFs are rebuilt here, from the submodule at the commit this repo
points to:

```
git submodule update --init                  # once per clone
git -C resume pull                           # or commit the change in resume/
make resume     # regenerates and copies both PDFs into assets/pdf/
git add resume assets/pdf && git commit -m "update resume"
make build && make deploy
make bust-cache PATHS="/assets/pdf/*"
```

`_config.yml` excludes `resume`, so its sources are never published; only the
two PDFs are.

The CV is not edited in `resume/cv.tex`: `make resume` generates it from the
same data the experience page shows (`_data/experience.yaml`,
`education.yaml`, `presentations.yaml`), through the template
`resume/cv.tex.erb`, with `scripts/generate-cv.rb`. Change what the CV says
in the data, and how it looks in the template; then commit the regenerated
`cv.tex` in the resume repo, so it still builds on its own. In the data,
`cv: false` leaves an entry out of the CV; the comment at the top of
`_data/experience.yaml` describes every field.

**Everything at once.** One wildcard costs a single path rather than one per
file, and beats listing more than a handful:

```
make bust-cache PATHS="/*"
```

## travel.mcknight.io

`travel/` is a **second Jekyll site** in this repo, serving the subdomain. It has
its own `_config.yml`, data, assets and page. The parent excludes it, so neither
site renders or copies the other; both share the one `Gemfile`, so there is a
single set of gems to keep current.

```
make build travel    # build it into travel/_site/
make serve travel    # read it at localhost:4500
make deploy travel   # upload it to its own bucket
```

Browsers resolve any `*.localhost` name to 127.0.0.1 with no `/etc/hosts` entry,
so `http://travel.localhost:4500` works too and reads more like production.

The introduction above the globe is written in Markdown in
`travel/_includes/intro.md`, as on the books site, and is left out while that
file is empty. With one, the globe is sized to the screen rather than to the
room left under it.

### The page

An interactive globe. Drag to turn it, scroll or pinch to move closer, double
tap and drag to zoom with one thumb, and click a continent, country, region or
place — on the globe or in the list beside it — to centre and magnify it with
everything else faded back. Escape, the button, or a click on the ocean leaves
that focus.

The list is a collapsible tree written by the server, so the whole hierarchy is
readable, collapsible and reachable by keyboard with no JavaScript at all.
It opens on continents and their countries; within a region, each kind of place
has its own subheading, and focusing a region opens them. On a wide screen the
list starts folded away to the right, to give the globe the room; its button
brings it back, and choosing anything on the globe unfolds it to show where.

Six layers, each with a checkbox in the legend, which doubles as the control
panel. High marks and trips each have a bordered group of their own in it:

| Layer | Drawn as | Comes from |
|---|---|---|
| Country visited | pale fill | `assets/geo/countries.json`, matched on ISO 3166-1 |
| State, province or region | strong fill | `assets/geo/regions.json` |
| City | black dot | `_data/cities.yml` |
| Point of interest | green dot | `_data/pois.yml` |
| High mark | blue dot, with its height | `_data/high_marks.yml` |
| Trip | a line, one colour per type, with a key in its legend group | `_data/trips.yml`, line in `assets/geo/trips.json` |

Unticking *countries* paints the visited ones like everywhere else rather than
removing the land, since the country layer **is** the land. Heights are stored
once in metres and shown in feet or metres from the control after *not yet*.

In the high marks group, a histogram of the high marks by height sits over a
slider with two handles. Moving them hides the high marks outside the range on
the globe, and greys them in the list; choosing a greyed one widens the range
just enough to take it in. The buckets are equal steps of round height (500 ft,
200 m), not percentiles, because percentile buckets all hold the same number of
places and would draw a flat histogram. The handles move one bucket at a time.
Within a region, high marks are listed highest first, so the region's high mark
is the first one.

### The data

`travel/_data/` is the only source. It holds one flat list per kind of record,
the way a database holds one table per kind, and each record points at others
by id:

| File | A record has | Its id |
|---|---|---|
| `countries.yml` | `code`, `name`, `continent` | `code` (ISO 3166-1) |
| `regions.yml` | `key`, `code`, `name`, `country`, `kind` | `key` |
| `cities.yml` | `id`, `name`, `region`, `lat`, `lon`, `dates` | `id` |
| `pois.yml` | `id`, `name`, `regions`, `lat`, `lon`, `dates` | `id` |
| `high_marks.yml` | `id`, `name`, `regions`, `lat`, `lon`, `elevation_m`, `dates` | `id` |
| `trips.yml` | `id`, `name`, `type`, `regions`, `dates`, `activities`, `track_activity` | `id` |

- A region's **key** is its ISO 3166-2 `code`, or its country and name when it
  has none, such as `IT:Tuscany`. The page and the geometry both use the key.
- A region's **kind** says what the second level is called in that country:
  state, province, territory, region, prefecture, county, federal district. The
  home page counts a US region as a state only when its kind is `state`, so the
  District of Columbia is not one.
- A city is in one region. A **point of interest** or a **high mark** is in any
  number of regions, because a national park or a summit on a state line can
  be in more than one. It shows under each of them in the list, and as one dot.
- You choose the regions yourself. Nothing finds them from the coordinates,
  because `make travel-check` compares the coordinates with the regions, and
  that comparison is how a bad geocode is found.
- **dates** is an optional list. Each item is a day (`2019-06-12`), a month
  when the day is not known (`2024-03`), or a stay (`from:` and `to:`). A place
  appears once, however many times you went; each visit is a date.
- Points of interest are areas (parks, trails, caves), so they have no
  elevation. Only high marks have one.
- A **trip** is a route you have done, drawn as a line: a hike, a ride, a
  rafting trip. Its `type` is any text (`hike`, `packraft`, `nordic ski`),
  kept in lower case so one type has one spelling. There is no fixed list: the
  admin app suggests the types already used, and the globe gives each type in
  the data its own colour, the most used types first, and lists them in the
  legend with their counts. It has one line however many times you did it;
  each time is a date, and each Strava activity it came from is in
  `activities`. `track_activity` is the one
  whose line is drawn. The lines are in `assets/geo/trips.json`, not in the
  YAML, because a line is hundreds of points.

`lib/travel/store.rb` reads and writes these files, and checks each record
before it saves it: a name, a region that exists, coordinates in range. The
admin app and the scripts all go through it, so a later move to a database
changes that one file. Because the Store writes the files, they have no
comments; the notes are here instead.

### The admin app

```
make travel-admin    # then open http://localhost:4600
```

A local web app for the data, so you do not have to edit the YAML by hand:

- **List, add, change and delete** every kind of record. A list has a filter
  box. A record that others point at (a region with cities in it) cannot be
  deleted.
- **Rename safely.** Change a country's or a region's code and everything that
  points at it is changed too. The id of a city, point of interest or high mark
  never changes, so renaming one breaks nothing.
- **Find coordinates.** The button on a place's form looks the name up in
  Nominatim, with its region and country as context, and shows the form again
  with the answer filled in, with a link to see the point on OpenStreetMap. It
  does not save; you check the answer first. For a high mark it also gets the
  elevation.
- **Region check.** Each place's list row and form show whether its
  coordinates are inside its regions, and the front page lists every place that
  has no coordinates or is outside its regions, and every region not yet drawn.

It listens on 127.0.0.1 only and has no login, so it is for your own machine.
Every form carries a token from your session, so a different site open in the
same browser cannot send a change to it. It saves to `travel/_data/`, so you
review with `git diff`, commit and deploy as usual. After you add a country or
a region, run `make travel-geo` so the globe can draw it.

To try something on a copy of the data first, point the app (or any script) at
another folder. `PORT` changes the port:

```
TRAVEL_DATA=/tmp/travel-data PORT=4601 make travel-admin
```

### Trips from Strava

*Import from Strava* in the admin app makes trips from a Strava data export
(Strava → Settings → My Account → Download or delete your account). Drop the
zip Strava sends, or the folder it unzips to, on the import page; drop several
to switch between them. Only `activities.csv`, `privacy_zones.csv` and the
tracks are sent to the app, which keeps them in a temporary folder outside the
repository and deletes it when it stops, so each run starts with no export.

1. **Find** the activities worth keeping: filter by name, type, year, shortest
   distance, and whether one is imported already.
2. **Look** at one. Its line is drawn twice: solid, what the trip keeps, and
   faint, what is removed. Removed are GPS errors (below), the points inside
   the export's privacy zones, and 500 m at each end, since most activities
   start and stop at home; change the 500 m and redraw if an end needs more or
   less.
3. **Make a trip** from it, or **add it to a trip** already made. A new trip
   takes the activity's name, a type, and the regions the line passes through.
   Adding to a trip adds the date, and can also replace the trip's line.
   A new trip's type starts as Strava's (`Nordic Ski` becomes `nordic ski`);
   change it to any type, or to one already used.
4. **Or make many at once.** Tick activities in the list (the box in the
   header ticks every one shown) and *Make trips from selected*. Each becomes
   its own trip with the defaults its page would offer: Strava's name and type,
   the regions along its line, the same trimming. One that cannot be a trip is
   skipped and named with why: already a trip, no GPS track, too short once its
   ends are removed, or in no region drawn on the globe yet. Rename them on
   the Trips page after. A repeat of a trip you already have is better added
   to that trip from the activity's own page, since bulk import makes every
   activity a new trip.

The date is the day the activity started where it started: Strava's dates are
UTC, which would put an evening in the Americas on the next day.

What a trip keeps is simplified to about 15 m, and rounded to about a metre,
so a long day is a few hundred points. The page shows *Add it as a high mark*
with the highest point of the track, but GPS heights are often tens of metres
out; for a summit, the surveyed height is better.

**GPS errors** are found by cutting the track wherever one point cannot
follow from the one before: reached at over 300 km/h, or more than 2 km away
after a pause of more than 5 minutes (a fix left over from the drive to the
start). The pieces with fewer than 5 points are dropped: a spike is a piece of
one point, a cluster of bad fixes a piece of two or three. A real jump, such as
a track that carries on after a shuttle, leaves long pieces on both sides, and
both stay. Across the whole export this removes points from 22 of 1,046
activities, at most 8 from any one; the worst ride went from 45 times its
distance to the right length.

Tracks are GPX, TCX or FIT, gzipped or not, as Strava exports them. Only the
position, height and time of each point are read. An activity recorded without
GPS (an indoor swim, a gym workout) has no line to import.

If the export is in iCloud Drive, its files may be in the cloud only, and each
is downloaded the first time it is read; set the folder to *Keep Downloaded* in
Finder to make browsing fast.

### Keeping it honest

Nothing is fetched while the page builds or while a visitor reads it. Every
coordinate, height and polygon is committed. Three commands produce them, and
all are safe to re-run:

- **`make travel-geocode`** adds `lat:`, `lon:`, and for a high mark
  `elevation_m:`, to anything lacking them, through OpenStreetMap's Nominatim.
  A place that already has coordinates is skipped, and the file is saved after
  **every** answer — a run cut off halfway keeps what it found. Nominatim allows
  about one request a second and answers HTTP 429 when it has had enough; that is
  waited out and retried with a growing pause, and after several refusals the run
  stops and asks you to try later. A height comes from OpenStreetMap's surveyed
  `ele` where there is one, and from a terrain model otherwise — the model
  samples a 90 m grid, so it reads summits low and knows nothing about buildings.
- **`make travel-geo`** rebuilds the geometry from [Natural
  Earth](https://www.naturalearthdata.com), which is public domain. Sources are
  cached in `travel/.geo-cache/` (ignored by git); the first run downloads about
  43 MB and later runs read the cache. Only the filtered result is committed.
- **`make travel-check`** tests every located place against the polygon of the
  region it is filed under, or any of the regions it names. It also reports a
  place whose region does not exist in `regions.yml`. It needs no network.

A geocoder is confidently wrong often enough to matter. `Gray's Peak` landed in
Oklahoma, `Painted Desert` in Anaheim, `Skyline Drive` on a street in Norfolk,
`Ka Lae` on Kauai and `Kapa'au` on Molokai. The region check catches the first
three; the last two it cannot, because a wrong answer inside the right region
looks right. **Read new coordinates before trusting them.**

### Why a region is found three ways

A region is looked for by ISO code, then by name within its country, and only
then by the places inside it. The first two fail often enough to need the third:
many regions carry no code, and Natural Earth models some countries at a
different level than this data does — France as *départements* rather than
régions, Italy and the Philippines as provinces, Czechia under a code of its
own.

So a region neither a code nor a name finds is located by its places: every
polygon containing one of its places is a polygon to fill. All matches are kept,
not the first, or Tuscany would highlight the province holding Pisa and lose the
one holding Florence. A place up to 25 km outside still counts, because a coastal
city often geocodes to the water — Genoa lands in its old port, which Natural
Earth's coastline excludes.

Two details of the geometry are worth knowing, because both have bitten:

- The **`_lakes`** variants of the Natural Earth files are used, where the Great
  Lakes are cut out. In the plain files a state's boundary runs out into the
  water, and Michigan is one polygon that swallows Lake Michigan instead of the
  two peninsulas either side of it.
- Simplification **drops a ring it cannot preserve** rather than repairing it.
  On a sphere there is no outside: a ring wound the wrong way describes
  everything except itself, so one broken ring paints the whole globe in that
  country's colour. Antarctica's pole-following boundary and a sliver of Malawi
  in the lakes file have each done it.

### The main site counts from the same files

The home page sentence — *"I've visited 38 US states and 14 countries across 4
continents"* — is counted from `travel/_data/` at build time, so it cannot fall
behind the map.

The main site excludes `travel/`, which also hides those files from Jekyll's
own data loading, so `_plugins/travel_data.rb` reads them and puts them in
`site.data.travel` for the main site too: `site.data.travel.countries`,
`site.data.travel.regions` and so on. One copy of the data, two sites.
A US state is a region with `kind: state`, which is why the District of Columbia
is not counted as one.

One wrinkle: because `travel/` is excluded, `jekyll build --watch` on the main
site does not notice edits to the travel data. Re-run `make build` after changing
it.

### A place is framed by where you went in it

Focusing a country aims at its cities, not at its outline. France's geometry
reaches from French Guiana to Réunion and Alaska's crosses the date line, so
framing either by its bounding box aimed the camera at open ocean. A country
with no place recorded yet falls back to its geometry.

## books.mcknight.io

`books/` is a third Jekyll site, set up like `travel/`: a globe of where the
authors on my Goodreads shelves were born, each country coloured by how many
authors are from it, on a logarithmic scale so that three and fourteen read
apart while one country holds half of them, with a dot for each birthplace and
a list of countries, authors and books beside it. A switch at the top chooses
the shelf shown — read, reading or want to read — and the colours, dots and
list follow it. The header counts the countries with an author on the read
shelf and on the reading shelf, out of 195: the UN's 193 members and its two
observer states. The introduction above the globe is written in Markdown in
`books/_includes/intro.md`, and is left out while that file is empty.

```
make build books     # build it into books/_site/
make serve books     # read it at localhost:4501
make deploy books    # upload it to its own bucket
```

The data is made in five steps, each committed, so a build is offline:

| Step | What it writes |
|---|---|
| `make books-import CSV=…` | `books/_data/books.yml`, from Goodreads' library export (My Books → Import and export). The Goodreads books are replaced whole each time; books added by hand are kept. Only titles, authors, ISBNs, years, shelves and dates read are kept, never reviews, ratings or notes |
| `make books-authors` | `books/_data/authors.yml`: each author's Wikidata item, birth year and birthplace with its coordinates. Only new authors are looked up |
| `make books-states` | `books/_data/states.yml`, the 195 countries counted against, from Wikidata. Re-run only when that list changes |
| `make books-geo` | `books/assets/geo/countries.json` from Natural Earth, each author's `country:` today and the `state:` it is counted under — a territory under the state that governs it — and `books/_data/countries.yml` |
| `make books-history` | Each author's `then:`, the former state they were born in, and a report of the authors today's borders do not fit |

To add a book Goodreads does not have, append it to `books/_data/books.yml`
with `manual: true`, then run `make books-update`, which looks up any new author
and runs the last three steps:

```yaml
- title: The Dispossessed
  author: Ursula K. Le Guin
  shelf: read            # read, currently-reading or to-read
  manual: true
```

A later import keeps it, until Goodreads has the same book (by title and
author); then the hand-made copy is dropped, and named, so it is not counted
twice.

Only the main author of each book counts. Goodreads' "additional authors" mix
co-authors with translators and does not say which is which, so they are kept
in `books.yml` but not counted.

A name is matched to a person on Wikidata by label or alias. When several
people share it, the one Wikidata records as the author of one of the books
wins, or else the best known, and that author gets a `check:` note in
`authors.yml`, as does one placed only by citizenship. To correct one, set its
`qid:`, delete its other fields but `name:`, and run `make books-authors` and
`make books-geo` again. A `then:` that Wikidata gets wrong can be written by
hand with `then_by_hand: true` beside it.

A birth date Wikidata knows only to the decade, century or millennium carries
`born_precision:`, and the page says "born 20th century" rather than a year it
does not know. A name that means no known author — Unknown, Anonymous — is
never looked up; it is listed under "Not on the map" as having no single
author.

The borders are today's, and so are the counts. An author born in a state that
no longer exists, such as Kafka in Cisleithania, is counted in the country that
holds their birthplace now, Czechia, and the list says what it was then.

## Shared by the subdomains

`shared/` holds what the travel and books sites both use: the globe's core
(`assets/js/globe-core.js` — the projection, sizing, turning, magnifying,
spinning, tooltip and camera — and `assets/css/globe-core.css`), and the fold
of the list beside the globe (`assets/js/outline-fold.js`), which starts
folded on a wide screen and unfolds when something is chosen on the globe.
Each site's own `globe.js` draws its layers on that core.

`shared/_plugins/shared_assets.rb` copies everything under `shared/assets/` into
a site's build, at the same path, so neither site keeps a copy in its sources.
A site loads it from its own `_plugins/shared.rb`, which is one
`require_relative` line; a `plugins_dir` setting would not do, because Jekyll
resolves a custom one from the shell's working directory rather than from the
site. A shared file must not share a path with a site's own file, which is why
the shared ones are named `globe-core`.

The main site excludes `shared/`, as it does `travel/` and `books/`.

## Hosting

The sites are separate from the DNS down: separate buckets, certificates and
distributions, sharing only the hosted zone. Nothing a subdomain does can reach
the main site, or another subdomain.

| | mcknight.io | travel.mcknight.io | books.mcknight.io |
|---|---|---|---|
| S3 bucket | `mcknight.io` | `travel.mcknight.io` | `books.mcknight.io` |
| CloudFront | `E3AJVW95W5JFMD` | `E2LVEB8WVCV9QY` | `E3EZKV7YFBDKD1` |
| Distribution domain | | `d2dwk99e4mo7s.cloudfront.net` | `d7avdl8bdvx1b.cloudfront.net` |
| ACM certificate (us-east-1) | `72f5b93c…` | `abe6c8e7…` | `35915606…` |
| Route 53 zone | `Z09242013GGZP8WGFDQP3` (all) | | |

All are configured the same way, and the Makefile holds each distribution id so
`make bust-cache travel` knows which one to invalidate:

- The bucket is a **website endpoint**, not a REST endpoint, with `index.html`
  as the index document and a public-read policy. CloudFront reaches it over
  plain HTTP as a custom origin — that is what gives directory URLs their index
  without any function at the edge.
- `DefaultRootObject: index.html`, viewer policy **redirect-to-https**,
  compression on, the managed **CachingOptimized** policy
  (`658327ea-f89d-4fab-a63d-7e88639e58f6`), PriceClass_All, HTTP/2, IPv6.
- The certificate is DNS-validated and lives in **us-east-1**, which CloudFront
  requires wherever the bucket is. The validation CNAME stays in the zone;
  deleting it would break renewal.
- `travel.mcknight.io` is an **A and AAAA alias** to the distribution, not a
  CNAME, using CloudFront's fixed zone id `Z2FDTNDATAQYW2`.

The one certificate does **not** cover both names: `mcknight.io`'s certificate
lists only that name, which is why the subdomain needed its own.

### Adding another subdomain

```
scripts/setup-subdomain.sh books.mcknight.io
```

does the five steps, in order, with the settings above: create the bucket and
give it a website config and a public-read policy; request a DNS-validated
certificate in us-east-1; put the validation CNAME in the zone and wait for
ISSUED; create a distribution aliased to the name; add A and AAAA alias
records. Every AWS command, read-only lookups included, is printed exactly as
it will run — with `--profile` and `--region` as flags, so it can be pasted and
run by hand — and runs only after a "y"; any other answer stops the script.
What each returns is printed after it. `PROFILE=` picks the AWS profile,
`armcknight` by default.

It can be run again: each step reuses what already exists, so a run that
stopped while the certificate was validating carries on from there.

It ends by printing the `bucket_` and `dist_` lines for the `Makefile` and the
values for the table above.

```
scripts/audit-subdomain.sh travel.mcknight.io
```

checks every one of those settings against what the setup makes — bucket,
certificate and its validation record, distribution, A and AAAA records, the
`Makefile` entries — and that the site answers over HTTPS and redirects HTTP to
it. It is read-only, prints each command it runs, marks each setting `ok` or
`WRONG` with what it found and what it expected, and exits non-zero if
anything is wrong. Its expected values are the setup script's; a change to one
belongs in both. The site also needs its place in `SITES` with its
own `src_`, `dest_`, `port_`, `stamp_`, `log_` and `label_` entries.

## Layout## Layout

| Path | What it is |
|---|---|
| `Makefile` | Every workflow, and the long-form explanation of each |
| `_config.yml` | Jekyll config. `url` is the origin every absolute link, feed entry and social-card image is built from, so it must match the scheme actually served |
| `_data/` | Content the templates read as data rather than markup — see below |
| `_layouts/`, `_includes/` | Templates. `_layouts/modern.html` holds the `<head>`, including the Open Graph and Twitter card tags |
| `_plugins/` | Jekyll plugins (tagging) |
| `blog/_posts/` | Posts, named `YYYY-MM-DD-slug.md` |
| `blog/img/` | Post images, including the optional per-post `thumbnail` |
| `scripts/new-post.sh` | Creates a post from a title, front matter and date filled in |
| `scripts/generate-cv.rb` | Writes `resume/cv.tex` from `_data/` through `resume/cv.tex.erb` |
| `scripts/fetch-releases.rb` | Generates `_data/releases.yml` and `_data/activity.yml` |
| `.github/workflows/nightly-refresh.yml` | Runs `make releases` nightly and on a `release-published` dispatch, and deploys when it changed |
| `scripts/nightly-refresh/` | The workflow's steps: refresh the data and say what changed, commit `releases.yml`, deploy and push the stamp |
| `travel/` | The travel.mcknight.io site: its own config, data, page and scripts |
| `books/` | The books.mcknight.io site: its own config, data, page and scripts |
| `shared/` | What the subdomains share: the globe's core, and the plugin that copies it into each build |
| `resume/` | Submodule of armcknight/resume: LaTeX sources for the resume and CV; `make resume` builds them |
| `assets/pdf/` | The built PDFs the site links to — these are the tracked artifacts, not `resume/build/` |
| `robots.txt` | Who may crawl the site: everyone, for search, link previews and AI answers, but not the crawlers that train AI models. `travel/` and `books/` have the same file. It names `sitemap.xml`, which `jekyll-sitemap` writes |
| `DEPLOYED` | What is live |
| `_site/`, `logs/` | Build output and transcripts. Untracked |

### Data files

`_data/*.yml` drives the pages that are lists of things, so adding an entry
never means touching markup.

| File | Feeds |
|---|---|
| `projects.yml` | The projects page: apps, devtools, coding challenges. Each devtool needs an `impact`, its rank by closeness to an end user (1 closest), unique among them, which the page sorts by; `make build home` checks this (`scripts/check-projects.rb`) and fails on a missing or shared one |
| `releases.yml` | Generated by `make releases`; the version and date on each project card |
| `activity.yml` | Generated by `make releases`, and ignored by git, from each devtool's commits: commits and lines added and deleted over the last year, 30 days and 7 days, with commits by week and by day for the page's bar charts. Each commit's line counts are cached in `.cache/commit-stats.json` (ignored by git), so a repeat run takes seconds |
| `experience.yaml`, `education.yaml`, `presentations.yaml` | The experience page |
| `links.yml` | The links page |

The travel data is not here: it belongs to the other site, in `travel/_data/`.

Two conventions worth knowing:

- **Release lookups.** A project's version normally comes from the latest release
  of the repo in its `website`. When a tool publishes to the `homebrew-tools` tap
  under a prefixed tag instead, its entry says so with `release-repo` and
  `release-tag-prefix`. App Store apps have no release to read, so their version
  comes from the iTunes lookup API. `releases.yml` is committed, which keeps
  builds offline and immune to rate limits — the versions shown are only as fresh
  as the last `make releases`, which `nightly-refresh.yml` runs at least nightly.
- **Social cards.** A post gets a card image only if its front matter sets
  `thumbnail:`, pointing at a file in `blog/img/`. Without one the card is title
  and description text, deliberately — there is no fallback image.

## Requirements

`make init` installs all of it: Homebrew and the `Brewfile` (awscli, exiftool,
imageoptim, TeX), the rbenv-pinned Ruby, and the gems. Run it again after
`Gemfile` or `Brewfile` changes.

Ruby comes from rbenv, so a bare `jekyll` outside `bundle exec` is the wrong one.

Beyond that:

- An AWS profile named `armcknight`, able to write the bucket and create
  invalidations. Used by `deploy`, `bust-cache`, and the cache-status target.
- `gh` logged in, for `make releases` — some of the source repos are private.
- A TeX distribution, for `make resume`.

## When something looks wrong

**A deployed change is not visible.** In order: confirm `make build` ran *after*
the edit; compare `curl -s https://mcknight.io/DEPLOYED | head -1` against your
commit; confirm the invalidation finished with
`make check-cache-invalidation-status`; then suspect your browser. An
invalidation naming a path that does not exist reports success and does nothing.

**"Refusing to deploy: the working tree has uncommitted changes."** Nothing was
uploaded. Commit or stash, rebuild, deploy.

**"Deploy finished, but something other than DEPLOYED changed."** The upload
succeeded and `DEPLOYED` was written but deliberately not committed. The tree was
verified clean before the sync, so anything else changing means something moved
underneath the deploy. Find out what, then commit `DEPLOYED` yourself.

**An image is large in the repo.** `make optimize-images` only touches images git
already reports as changed, so it does nothing for one already committed.
Optimize before committing, not after.
