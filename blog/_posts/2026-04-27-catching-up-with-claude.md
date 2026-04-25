---
title: Catching Up with Claude
date: 2026-04-27
author: Andrew McKnight
layout: post
tags: software engineering tech
abstract: Yet another post about LLM-assisted side projrct necromancy.
---

I was recently on some parental leave. And in some of the times where I'd be couchlocked under a newborn, I was able to still type, so I set Claude to work doing a few different things.

# Babysittr

First off, I built an app to help track baby stuff like feedings and diapers. We've looked at other apps in the past for this, but they're too heavyweight and don't work exactly how we'd like, so we wound up using a shared Apple note for our last baby. I personally prefer apps that sync over iCloud instead of a server controlled by the company that build the app, so this is how mine syncs data between mama and me. I actually started working on something like this with our previous baby, but never got very far. I built this one from scratch with SwiftUI, and it actually works and is helping us.

# mcknight.io

Some time ago, I bought a .rocks domain for personal email. I've come to regret that decision as plenty of systems don't accept it. Also, once I provided it on a handwritten form at a doctor's office, and the receptionist accusatively asked me what that letter was. Yeah, I have a .cocks TLD. _M'lady_.

So more recently I bought mcknight.io, with the side benefit that I could replace the _original_ domain I've used for myself for even longer, armcknight.com (mcknight.com was long gone by the time I wanted a domain for myself). I could roll everything up into one shiny new site.

But I've been procrastinating doing the move ever since. Well, I finally made it happen. After I copied over the sources myself to the new repo, I had Claude replace any references to armcknight.com with mcknight.io, including in the automation, like Makefile tasks. Then I had it write and deploy Cloudfront functions (I run all my websites on AWS) to redirect from armcknight.com to mcknight.io (and also, from an older business website I had, where my blog originally lived, tworingsoft.com). I already had the AWS CLI incorporated into my website automation, and since Claude is a perfect fit with text systems, it was able to do all the DSN and AWS nonsense easily via the CLI. It even fixed up obsoleted settings that had been around in my old S3/Cloudfront configs forever, since some were so old that those systems' best practices have udpated in the intervening years. The old website repos now simply contain the sources for those functions with Makefile tasks to deploy them using the AWS CLI invocations Claude created.

# Delaunay and Trgnmtry

I've had two toy apps on the app store for many years, one reaching back to my university years. But, both had been removed from listings due to being caught in the dragnet of Apple's modernization efforts. They wanted apps built against a minimum target, but with various work in flight in my app-building libraries, I was never able to get everything synced and up to speed before the deadline passed and they were removed. That was years ago now. I just didn't have the time between buying a home, having kids, working at a startup and having fun adventuring.

But now I was able to kill a couple birds there with Claude:

- modernize my app building library, including writing adapters for some new dependencies (XCGLogger -> SwiftyBeaver, Crashlytics -> Sentry, PinpointKit -> also Sentry). I also added some new core components from other more recent app development work I've done, like a "What's new" view in an app that displays any time an app upgrade is detected, that shows all the changelog entries between the last launched version and the new updated version. It also now includes an abstraction for the iCloud sharing from the Babysittr app mentioned earlier.
- split out all my little Swift extensions to a separate library to keep the app building library lean and focused
- combine a separate mathematical library into that Swift extensions library
- get it all working via SPM instead of CocoaPods
- rewrote some tools I had for release automation like managing semver, changelogs and git tags, from the Ruby gem they were in to a Swift package deployed via a Homebrew tap. This also combined in some other tools I had in separate repos but didn't really need to be, including an Xcode project build setting differ and a secrets manager. I also had it write new tools to deploy updates to GitHub releases and to inject git information into an app's info plist to attach it to events sent to app monitoring services for cross referencing issues.

After getting new builds uploaded for these apps, I was able to then tick off another longstanding desire of mine to transfer them off of the old business account I had for the App Store to a new personal account.

# Projects page

A while back I redesigned this website using Claude, and that included adding a new [Projects](/projects) page. At that time, basically every project listed there was in a defunct state. I'm happy to see it coming back to life!
