---
title: "My holy grail: a simple Rails install"
date: 2018-09-25
layout: post
abstract: Describing yet another winding foray into setting up a Rails app.
author: Andrew McKnight
author-email: andrew@tworingsoft.com
tags: ruby rails
---

Recently I got an itch to practice some backend fundamentals, and set up a few different stacks from scratch. First up is Rails, something I've worked with in the past and know to be a very well automated full stack solution. I've used Ruby since 1.8.7, so am comfortable with the language.

Setting up the stack, however, is still a process I have not mastered. I hit several roadblocks along the way to getting a working Rails app running, as is tradition harkening back to every other time I've attempted it. Working with the Ruby ecosystem is [complicated enough](https://github.com/CocoaPods/CocoaPods/issues/2238) that a [Homebrew formula](https://github.com/Homebrew/homebrew-core/blob/master/Formula/cocoapods.rb) was created to encapsulate installing the CocoaPods gem, which has been another plentiful source of adventure for me while working on iOS.

This time, I started by following [Heroku's guide](https://devcenter.heroku.com/articles/getting-started-with-rails5#create-a-welcome-page) and hit two problems: installing nokogiri and pg, both with native extensions. I waded through an ocean of GitHub issues and Stack Overflow posts to cobble something together that finally worked. So, I'll add my drops of knowledge to that yawning abyss. Here is a list of everything I did until I got a successful Rails app running locally.

1. configure rbenv:
    - `rbenv install 2.5.1`
    - `rbenv rehash`
    - `rbenv local 2.5.1`
2. install/configure bundler:
    - `rbenv exec gem install bundler`
    - `rbenv exec bundle config --global path vendor/bundle` # from [this GitHub Gist](https://gist.github.com/denvazh/9535921004d7208dd275); I like this model of keeping all dependencies in the project, instead of user/global directories, just like CocoaPods
3. suggested workarounds to install Nokogiri, from the macOS section of their guide ["Installing Nokogiri"](http://www.nokogiri.org/tutorials/installing_nokogiri.html):
    - `brew install libxml2 pkg-confif`
    - `brew uninstall --ignore-dependencies xz`
    - `xcode-select -switch` between my local versions of Xcode 10 and 9.4.1
4. `env ARCHFLAGS="-arch x86_64" rbenv exec bundle` # ARCHFLAGS workaround for pg gem: https://stackoverflow.com/questions/6209797/cant-find-the-postgresql-client-library-libpq)
5. `brew install xz` # don't forget this if you uninstalled it earlier!

Steps 4 and 5 are where I hit trouble. When bundling, I got some error messages about undefined symbols for the i386 architecture when building nokogiri with native extensions. I couldn't find anything on the web pointing out my exact problem, but many similar ones, so I chipped away by trying a few different things I found. (I must admit that I don't know which one alone would have fixed it. I tried resetting my machine and retracing all these steps again, only to have it work perfectly without hitting the same nokogiri issues.) The linked SO post in step 4 is the exact problem I had and I was able to translate the top solution for my needs (by removing `sudo` usage and replacing it with `rbenv`).

# One more thing...

From here it wasn't too much more to get to running the app in the cloud via Heroku. I had to fill in some steps of my own to get it working though–their guide did not have adequate coverage of local PostgreSQL usage. When I tried to run `rbenv exec bundle exec rails server` I got a fatal exception: `database "myapp_development" does not exist`. The [GoRails guide](https://gorails.com/setup/osx/10.13-high-sierra) filled in the gap there, where I'd hadn't yet run `rails db:create`. I also wound up needing to do the following for that to work:

- `brew install postresql`
- `createdb`

Finally, rerunning the Rails server was able to get me to the Heroku tutorial's welcome controller page. Whew... I have a working Rails app again! I committed it to [a GitHub repo](https://github.com/armcknight/rails-app) for preservation.

# Postscript

Funnily enough, I blew away some Ruby dependencies I use to compile this static site with Jekyll, Sass and a few plugins! I fixed it up, and it now uses the local `vendor/bundle` bundler path as well, and I even ran `bundle package` and checked `bundle/cache` into source control, while adding `bundle/vendor/**/*` to `.gitignore` (thanks to [this guide to bundler dependencies](http://ryan.mcgeary.org/2011/02/09/vendor-everything-still-applies/), which also enunciates dependency principles that resonate strongly with me; see also my previous writings [on dependency isolation](http://tworingsoft.com/blog/2018/01/09/dependency-management-best-practices.html)).
