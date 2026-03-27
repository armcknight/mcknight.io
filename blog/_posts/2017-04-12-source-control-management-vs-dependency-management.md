---
title: Source Control Management vs. Dependency Management
date: 2017-04-12
layout: post
abstract: Which manager has more authority over your project?
author: Andrew McKnight
author-email: andrew@tworingsoft.com
tags: git cocoapods ios
---

I've taken part many times in the debate on [whether to track the `Pods/` directory in source control](https://guides.cocoapods.org/using/using-cocoapods.html#should-i-check-the-pods-directory-into-source-control). I believe the dependencies should be tracked, and I want to try to explain the philosophy behind why I think the way I do. I'll do so by building from basic principles regarding tools developers use every day: compilers, source control managers and dependency managers. Bear with me for a moment, if you will:

## What is a compiler?

A compiler takes human-readable source code and translates it into machine-readable code. It doesn't know the difference between who wrote the code, whether it was that coder that got [hit by the bus](https://www.exceptionnotfound.net/whats-your-projects-bus-factor/) last week, or the five you had to hire to replace them.

Correspondingly, a linker takes the blobs of machine code output from the compiler and splices them together into one blob. This might include blobs made by other compilers at other times. As long as they are well formed and readable, the linker doesn't care whether the blobs were just spat out by the compiler ahead of it in the toolchain, downloaded from artifactory, or any combination of those and other possibilities.

## What is a source control manager?

Source control managers keep a record of the changes made to any text files it knows about, as a list of important milestones in that history recorded by the developer ("commits"). It does not care who commits those changes; they are recorded the same way every time.

**I believe that all code that a compiler will compile, and all blobs the linker will link, should be tracked** in a way that _guarantees_ an exact replica of a binary, with minimal friction, given a single identifier (commit hash or tag). This means that the simple act of checking out a commit should give you everything you need to build the final product. No calls out to the network to get the right dependencies, which brings us to...

## What is a dependency manager?

A dependency manager is a tool that takes a list of things you want to use, reduces duplications and (hopefully) conflicts, and retrieves those things. You pull a lever, and all the souce code and precompiled binaries are retrieved (usually over the network, whether it's an in-house LAN or the internet) and written into place on your disk.

Think again about my earlier statements about compilers, linkers and source control. They don't know or care about the originator of the code and blobs. On a more abstract level, a dependency manager is _really_ just another code author. You may not be keying in all the glyphs that make up [AFNetworking](https://github.com/AFNetworking/AFNetworking), but when you instruct CocoaPods to retrieve that library's code, you are metaprogramming to generate that source code on your machine. It then gets compiled and linked the same as your application code. Therefore I believe you should check in the code you've "written" using your dependency manager.

## Dependency managers today

I think we've heaped far too many responsibilities onto dependency managers today. If you don't check in your `Pods/` directory, you are using it to reconstruct a fragmented source history whenever you need to recreate a previous release. CocoaPods can also be used as a way to package precompiled binaries for distribution as others' dependencies. It makes assumptions about how your Xcode project should be structured, in terms of file locations, Xcode's File Navigator structure, build settings, artifacts and project/workspace/scheme organization. Too much can go wrong with a simple Xcode update. It's too many moving parts, period.

The only thing I want to do with CocoaPods is to pull that lever and update what I want updated. Then I can look at the diffs, commit the changes ([as its own commit!](http://tworingsoft.github.io/blog/2017/01/19/the-art-of-source-control-part-2-clean-git-history.html)), and I'll be able to get everything I need with a single checkout next time. I'll be able to traverse updates to my dependencies in the same way as updates to source code I manually type with my fingers, when I do my next `git bisect`. I won't have to worry about GitHub outages or source locations changing or [being removed](http://blog.npmjs.org/post/141577284765/kik-left-pad-and-npm) the next time my CI build kicks off and tries to download the dependencies all over again.