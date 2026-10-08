# mcknight.io

The source of [mcknight.io](https://mcknight.io): a [Jekyll](https://jekyllrb.com)
site built to `_site/`, served from an S3 bucket behind a CloudFront
distribution.

There is no CI. Publishing is a person running `make` on a workstation.

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

**Refresh the versions on the projects page.**

```
make releases
git add _data/releases.yml && git commit -m "refresh release data"
make build && make deploy
make bust-cache PATHS="/projects/ /projects/index.html"
```

**Change the resume.** Editing `resume/*.tex` changes nothing a visitor sees
until the PDFs are rebuilt, so do it in the same commit:

```
$EDITOR resume/cv.tex
make resume     # regenerates and copies both PDFs into assets/pdf/
make build && make deploy
make bust-cache PATHS="/assets/pdf/*"
```

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

### The page

An interactive globe. Drag to turn it, scroll or pinch to move closer, double
tap and drag to zoom with one thumb, and click a continent, country, region or
place — on the globe or in the list beside it — to centre and magnify it with
everything else faded back. Escape, the button, or a click on the ocean leaves
that focus. **Full screen** hides everything but the globe.

The list is a collapsible tree written by the server, so the whole hierarchy is
readable, collapsible and reachable by keyboard with no JavaScript at all.
Within a region, each kind of place has its own subheading; focusing a region
opens them.

Four layers, each with a checkbox in the legend, which doubles as the control
panel:

| Layer | Drawn as | Comes from |
|---|---|---|
| Country visited | pale fill | `assets/geo/countries.json`, matched on ISO 3166-1 |
| State, province or region | strong fill | `assets/geo/regions.json` |
| City | black dot | `cities:` in `_data/travel.yml` |
| Point of interest | green dot | `pois:` |
| High mark | blue dot, with its height | `highmark:` |

Unticking *countries* paints the visited ones like everywhere else rather than
removing the land, since the country layer **is** the land. Heights are stored
once in metres and shown in feet or metres from the control at the right of the
legend.

### The data

`travel/_data/travel.yml` is the only source. Continent → country → region →
places. A region may carry a `code:` (ISO 3166-2) but does not have to; without
one it is identified by its country and name.

A place is normally a list entry with a name:

```yaml
cities:
  - name: Boston
pois:
  - name: Acadia National Park
highmark:
  - name: Mt. Greylock
```

A single place may also be written in shorthand, which `make travel-geocode`
widens into the list form on its next run, because a string has nowhere to keep
a latitude:

```yaml
highmark: Mt. Greylock
```

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
  region it is filed under. It needs no network.

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

### The main site counts from the same file

The home page sentence — *"I've visited 38 US states and 14 countries across 4
continents"* — is counted from `travel/_data/travel.yml` at build time, so it
cannot fall behind the map.

The main site excludes `travel/`, which also hides that file from Jekyll's own
data loading, so `_plugins/travel_data.rb` reads it and puts it in
`site.data.travel` for the main site too. One file, two sites, no copy to drift.
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

## Hosting

The two sites are separate from the DNS down: separate buckets, certificates and
distributions, sharing only the hosted zone. Nothing the subdomain does can
reach the main site.

| | mcknight.io | travel.mcknight.io |
|---|---|---|
| S3 bucket | `mcknight.io` | `travel.mcknight.io` |
| CloudFront | `E3AJVW95W5JFMD` | `E2LVEB8WVCV9QY` |
| Distribution domain | | `d2dwk99e4mo7s.cloudfront.net` |
| ACM certificate (us-east-1) | `72f5b93c…` | `abe6c8e7…` |
| Route 53 zone | `Z09242013GGZP8WGFDQP3` (both) | |

Both are configured the same way, and the Makefile holds each distribution id so
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

The same five steps, in order: create the bucket and give it a website config
and a public-read policy; request a DNS-validated certificate in us-east-1; put
the validation CNAME in the zone and wait for ISSUED; create a distribution
aliased to the name; add A and AAAA alias records. Then add the site to `SITES`
in the `Makefile` with its own `src_`, `dest_`, `port_`, `bucket_`, `stamp_`,
`log_`, `label_` and `dist_` entries.

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
| `scripts/fetch-releases.rb` | Generates `_data/releases.yml` |
| `travel/` | The travel.mcknight.io site: its own config, data, page and scripts |
| `resume/` | LaTeX sources for the resume and CV; `make resume` builds them |
| `assets/pdf/` | The built PDFs the site links to — these are the tracked artifacts, not `resume/build/` |
| `DEPLOYED` | What is live |
| `_site/`, `logs/` | Build output and transcripts. Untracked |

### Data files

`_data/*.yml` drives the pages that are lists of things, so adding an entry
never means touching markup.

| File | Feeds |
|---|---|
| `projects.yml` | The projects page: apps, devtools, coding challenges |
| `releases.yml` | Generated by `make releases`; the version and date on each project card |
| `experience.yaml`, `education.yaml`, `presentations.yaml` | The experience page |
| `links.yml` | The links page |

The travel data is not here: it belongs to the other site, at
`travel/_data/travel.yml`.

Two conventions worth knowing:

- **Release lookups.** A project's version normally comes from the latest release
  of the repo in its `website`. When a tool publishes to the `homebrew-tools` tap
  under a prefixed tag instead, its entry says so with `release-repo` and
  `release-tag-prefix`. App Store apps have no release to read, so their version
  comes from the iTunes lookup API. `releases.yml` is committed, which keeps
  builds offline and immune to rate limits — the versions shown are only as fresh
  as the last `make releases`.
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
