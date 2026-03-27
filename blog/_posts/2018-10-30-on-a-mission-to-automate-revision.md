---
title: "On a Mission to Automate Revision"
date: 2018-10-30
layout: post
abstract: Introducing a new tool as part of my evolution towards effortless versioning of code.
author: Andrew McKnight
author-email: andrew@tworingsoft.com
tags: tools ruby
---

I've [written](/blog/2017/12/17/easy-versioning-with-vrsnr-and-rake.html) a [few](/blog/2018/04/20/automatic-devpod-versioning-and-deployment-with-vrsnr.html) times now about how I've slowly automated versioning for apps, SDKs and devtools. Today I wrote a new Ruby tool to help a bit with the process: `changetag`, the newest component of my [`tworingtools`]((https://github.com/tworingsoft/tools)) [Gem](https://rubygems.org/gems/tworingtools). Let's see what I've been up to, how the process is changing, and what `changetag` does to help.

# Keep a Changelog

One thing I've started since the last writing about version numbers is trying to build a habit of keeping an up-to-date changelog. And wouldn't you know it, there's a standard for it: [_keep a changelog_](https://keepachangelog.com/en/1.0.0/).

{% include blog-post-image.html source="https://imgs.xkcd.com/comics/standards.png" alt="From <a href='https://xkcd.com/927/'>https://xkcd.com/927/</a>" external="true" narrow="true" %}

Once nice thing about standards is that it allows ease of automation. Once I have a predictable format, I can start writing code that exploits the consistency to shuffle things around for me.

{% include blog-post-image.html source="https://imgs.xkcd.com/comics/automation.png" alt="From <a href='https://xkcd.com/1319/'>https://xkcd.com/1319/</a>" external="true" narrow="true" %}

# Git a Grip

[Vrsnr](https://github.com/tworingsoft/vrsnr) helps change the version numbers wherever they may reside, via a consistent interface at the command line. I have a [Rake task to make the change and commit it to git](https://gist.github.com/armcknight/8c2def2f9c0ba6714611a28ce14f1a0e), which I've been copying around for a while now (I know, that's gross–I'm thinking about how to share it, or integrate it into Vrsnr). Then I have a separate [Rake task to create a git tag and push](https://gist.github.com/armcknight/be6c3d33305b720cd48cba71e1088fc2) to the necessary places (git remotes, dependency servers).

# Put the Ease in Release

`changetag` extracts the relevant entry from your changelog and writes it into the message of a [git tag annotation](https://git-scm.com/book/en/v2/Git-Basics-Tagging). This way your release notes are neatly encapsulated with the version number, all in the milestone mechanism provided by source control.

GitHub lists each tag you push under a “Releases” tab, and will include by default any message written into the tag's annotation. You may also edit the release notes through the web UI or the GitHub API to make nicely formatted markdown notes. This is not yet done in `changetag` yet but is planned for the future. In the meantime, the notes are still listed there.
