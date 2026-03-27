---
title: Differentiating iOS App Builds
date: 2017-04-01
layout: post
abstract: A simple way to manage all your app build variants to test alongside each other on a device.
thumbnail: app-icon-for-different-app-build-distributions.png
author: Andrew McKnight
author-email: andrew@tworingsoft.com
tags: ios xcode
---

In the course of developing, testing and distributing your app, different types of builds are produced. If you test these on a device, one might overwrite the other, or even a live version you've downloaded from the app store just to make sure [everything works](/blog/2017/03/26/validating-crash-reporting-in-live-ios-apps.html). In this post, I'll propose some simple strategies to keep all of those builds separate and easily distinguishable on your test devices.

# Bundle IDs

First things first: prevent debug, beta, and app store builds from overwriting each other on your test device. To do this, add a suffix to each of your non-app-store builds so they register as "different" apps on your iDevice. Here's my setup:

{% include 
	blog-post-image.html 
	source="bundle-identifier-suffixes-for-different-app-build-distributions.png" 
	alt="Adding suffixes to bundle identifiers prevents build variants overwriting each other on device." %}

# App icons

Once you have multiple versions of your app on your device beside each other, you need a way to tell them apart. Inspired by [Krzysztof Zabłocki's KZBootstrap](https://github.com/krzysztofzablocki/KZBootstrap), I wanted to overlay some information about each build onto the icons, depending on the build variant. While `KZBootstrap` seems like an amazing tool, I already had an Xcode project, and I wanted to insert a clean, minimal solution. I also didn't want to bring any new dependencies in, like `imagemagick` and `ghostscript` as in `KZBootstrap` and a few other solutions I found online. 

After a little more searching, I found [`XcodeIconTagger`](https://github.com/bejo/XcodeIconTagger) which only uses macOS' Automator with a Quartz filter. I modified it to get a little more flexibility out of it in [this fork](https://github.com/TwoRingSoft/XcodeIconTagger). Now, I can create _Run Script_ Build Phases surrounding the _Copy Bundle Resources_ Build Phase that first create the icon overlay, and then after copying the icons to the installation, reset the git index to discard the changes.

{% include 
	blog-post-image.html 
	source="xcode-icon-tag-build-phases.png" 
	alt="The Build Phases in Xcode to tag and restore app icons for build variants." %}
	
`tag-icons.sh` is a script that wraps some of the different types of overlays I'd like, depending on the build variant, into a convenient interface to which I can simply supply either `tag` or `cleanup` commands. (It can be found in [shared-utils](https://github.com/TwoRingSoft/shared-utils).) The conditional logic that decides what to display, and invocation of the underlying tool itself, is handled inside:

{% include gist-embed.html url="https://gist.github.com/armcknight/63b8c731215402b52908dd5ad9f8f1a6" %}

Now, I can tell all my builds apart on my device at once. Here I have a debugging development build, displaying the git commit hash that built it; a beta build, showing the semantic and build versions; a special build that visualizes touch input, which I use to create App Store preview videos; the App Store version itself, with no overlay.

{% include 
	blog-post-image.html 
	source="app-icon-for-different-app-build-distributions.png" 
	alt="Overlaying build variant information on app icons helps differentiate them on device." 
	narrow="true" %}
