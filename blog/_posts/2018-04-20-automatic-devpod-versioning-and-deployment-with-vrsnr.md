---
title: Automatic Devpod Versioning and Deployment with Vrsnr
date: 2018-04-20
layout: post
abstract: Describing my process for semantically versioning the Pippin podspec, deploying it to CocoaPods trunk, and committing all the results to git history.
author: Andrew McKnight
author-email: andrew@tworingsoft.com
tags: ios cocoapods products
---

I previously talked about how I used [Vrsnr](https://github.com/tworingsoft/vrsnr) in a Rake task to bump version numbers in [“Manage version numbers with this one line command”](http://tworingsoft.com/blog/2017/12/17/easy-versioning-with-vrsnr-and-rake.html). At the time, I was using it in an iOS app's codebase, bumping its build and version numbers as I pushed out beta builds. But, as I worked on that and other apps that use [Pippin](https://github.com/tworingsoft/pippin), I also continuously updated it, and needed to push new versions of its podspec for consumption back in those apps.

# Versioning, v2

In Pippin's repo, I'm still using the same Rake task as before, but with a few tweaks since I last wrote it (you can see the old version in the old post). Previously, it always popped a stash off the stack at the end, but that wouldn't be necessary if nothing was stashed as part of running the task. Hence, changes from who knows when would've been placed in the working index, confusing the programmer; now it checks if any changes are present before stashing, and only pops a stash if there were changes. Also, it no longer creates a git tag... that's coming later on in the post.

{% include gist-embed.html url="https://gist.github.com/armcknight/8c2def2f9c0ba6714611a28ce14f1a0e" %}

Afer running this in Pippin's repo, the podspec's version has been incremented and the change is committed with a descriptive message: `Updated version from 4.2.0 to 4.3.0 in Pippin.podspec`. Next, I run a new Rake task written to release the pod: 

{% include gist-embed.html url="https://gist.github.com/armcknight/be6c3d33305b720cd48cba71e1088fc2" %}

This is what creates the git tag we mentioned earlier (using Vrsnr's `--read` function), pushes that tag, and pushes the podspec to the CocoaPods trunk. The nice thing about separating the bumping of version and tagging is it allows you to do any branch work necessary for your git flow before creating the tag, so it doesn't wind up pointing to orphaned commits or other strange things you might not want.

[Here is the entire Rakefile I use in Pippin.](https://github.com/TwoRingSoft/Pippin/blob/develop/Rakefile)

# The Devpod Cycle

Once I've found something I want to add in Pippin for use in whatever app I'm in at the moment, my flow looks like this:

1. `pod install` in the app repo, pointed at my local checkout of Pippin in the Podfile
2. make the changes in Pippin
3. run `rake bump[minor]` (or whatever component needs it), then `rake release`
4. back in app's repo, `pod install` without the path declaration to pick up the new version from trunk
5. commit changes using new Pippin functionality along with any tracked CocoaPods diffs from `pod install`

Five steps to get the changes in my devpod, push them to trunk, and get them back in the app, with everything properly tracked in version control. The only other thing is that path declaration in the app's Podfile–I don't like having to hand edit that kind of thing, dirtying my git index. So, I use environment variables:

{% include gist-embed.html url="https://gist.github.com/armcknight/441d7f6b86e746cd619134ea64ce8c20" %}

With that, `pod install` grabs the production version, and `PIPPIN_PATH=/path/to/.../pippin pod install` grabs it from a local checkout (in Fish shell, `env PIPPIN_PATH=/path/to/.../pippin pod install`). So, I'm using the latter in step 1, and the former in step 4.

# Pedantic Versioning

I'm a strong believer in semantic versioning, because it makes reasoning about and automating dependencies easier. Just as well, I strongly believe in maintaining auditability and reproducibility through version control. [Vrsnr](https://github.com/tworingsoft/vrsnr) helps you do both, please consider using it and helping make it better–it's designed with extensibility in mind, to cover more types of dependencies, ecosystems and platforms!
