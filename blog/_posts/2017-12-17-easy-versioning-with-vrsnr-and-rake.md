---
title: Manage version numbers with this one line command
date: 2017-12-17
layout: post
abstract: How I'm currently using Rake to automate a few common tasks I carry out to manage my iOS apps' version numbers.
author: Andrew McKnight
author-email: andrew@tworingsoft.com
tags: products
---

Having produced both iOS apps and developer tools used in them, I feel very strongly about using [semantic versioning](https://semver.org). It's a small price to pay to avoid all sorts of headaches, potentially for many more people than yourself. In my opinion, there's no reason not to do it. 

Maybe you don't like the hassle of editing that one line in that config file, and coming up with a commit message for the banal change? And then also maybe tagging it with the exact same template you used for all the other tags (after 2.4.17, because that's when you started/stopped prepending a "v" to it)? Or maybe you've just forgotten one of the steps in the midst of hot-patching a critical bug?

Well, I have seen and/or done all of these things at some point. That's why I wrote [Vrsnr](https://github.com/tworingsoft/vrsnr) to help alleviate the problem for myself. And as if that weren't simple enough, I automated the automation in a Rake task:

{% include gist-embed.html url="https://gist.github.com/armcknight/8c2def2f9c0ba6714611a28ce14f1a0e/61e05c2626679f2be5ef19add61db3f8846d7de0" %}

After git stashing `--all` of your working index, this will:

- use Vrsnr to bump the specified version component
- commit the change with Vrsnr's confirmation output as the message ("Updated CFBundleVersion from 6 to 7 in my/application/Info.plist")
- use Vrsnr's `--read` to get the version information back out and create a git tag

and then pop the stash to resume your regularly scheduled programming.
