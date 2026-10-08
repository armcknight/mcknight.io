# mcknight.io

The source of [mcknight.io](https://mcknight.io): a [Jekyll](https://jekyllrb.com)
site built to `_site/`, served from an S3 bucket behind a CloudFront
distribution.

There is no CI. Publishing is a person running `make` on a workstation.

```
make init     # once per machine
make build    # render into _site/
make serve    # read it at localhost:4000
```

`make` on its own lists every target with a one-line summary, and
`make help-<target>` prints the long explanation of one — `make help-deploy`,
`make help-bust-cache`. Those live in the `Makefile` beside the recipes they
describe, so they cannot fall out of step with them. This file covers what a
target list has no room for.

## How publishing works

Three steps, and **none of them implies another**:

1. **`make build`** renders the sources into `_site/`.
2. **`make deploy`** syncs `_site/` to S3 and records the commit it uploaded.
3. **`make bust-cache`** invalidates CloudFront, or visitors keep the old page.

`deploy` uploads whatever is already sitting in `_site/`, so deploying without
building first ships the *previous* build. It refuses to run from a dirty
working tree, because the commit hash it records could not otherwise describe
what was uploaded.

### What is live

`deploy` writes `DEPLOYED`, uploads it with the site, and commits it:

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
rbenv exec bundle exec jekyll build --drafts --destination _site
```

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

## Layout

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
| `travel.yml` | Places visited, for a future visualization. Not rendered yet |

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
