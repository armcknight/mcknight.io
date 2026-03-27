---
title: Overusing Xcode Targets Misses the Mark
date: 2018-05-08
layout: post
abstract: Outlining the differences between Xcode project targets and build configurations, and how to properly use each one.
author: Andrew McKnight
author-email: andrew@tworingsoft.com
tags: ios xcode
---

Many Xcode projects I've seen use multiple targets to build variants of the same application, when different build configurations would suffice. Of course, some of these are my own projects, which I'm fixing over time, but I've seen this in the majority of projects I've inherited as well. Let's talk about what each thing is and some tips to help you decide which to use–for more information, here is an [excellent and detailed writeup of targets, configurations and schemes](https://pewpewthespells.com/blog/using_xcode_targets.html).

# Targets

An Xcode target represents a distinct application, or program that runs on a computer.

Even if they share a lot of the same code, deployments on iOS, Watch and TV are all separate applications. Those platforms are inherently different and are meant for unique use cases, hence different ways of doing things. Certain tasks may be better suited towards a particular platform, so even though you may be a bank with an app on a phone and watch, they probably do different things.

Unit test suites are other kinds of applications, as are all the other extensions you can deliver in an app, like iMessage sticker packs. Even though targets are also used for frameworks and libraries, I do not consider them to be applications–they are parts of applications. A cabin is made out of logs; would you call a log a cabin? I have a slightly different set of rules for them, which I allude to later.


# Build Configurations

Suppose you're developing that bank app on iOS. Due to certain export regulations, you may need to deliver a modified version to users in a certain country. For each of your features and bugfixes, a QA build must be generated for internal testing. Still another flavor of the app is sent to your client for on-site testing and acceptance before shipping.

All of these things can be achieved using build configurations. The differences for these types of things can be expressed in the following build settings:

- `GCC_PREPROCESSOR_DEFINITIONS` and `SWIFT_ACTIVE_COMPILATION_CONDITIONS` to conditionally compile code
- `INFOPLIST_FILE` if you want to store things like server endpoints in your plist instead of in code
- `OTHER_LDFLAGS` to conditionally link certain frameworks, like intrusive debugging tools, or touch visualizers
- `PRODUCT_BUNDLE_IDENTIFIER`: different ids means you can have all the different app variants alongside each other, and
- `ASSETCATALOG_COMPILER_APPICON_NAME` helps you differentiate those variants, especially if you don't want to vary `PRODUCT_NAME`

# // TODO:s and Dont's

Do not create a target, configuration, and maybe even scheme, for each app variant. For an app with 3 variants, this creates 27 possible combinations. That is 24 too many! Even though you only hook up the right combinations today, others might not get it right later, and might be afraid to delete the unnecessary stuff.

You can't compile different sets of source files between configurations, as those are defined in a target's Compile Sources Build Phase. I'd argue that you should place [semi-]shared code into separate static libraries and link them in `OTHER_LDFLAGS`.

Each build setting's configuration specialization can be further broken down by iOS/macOS/etc SDK versions. This is very helpful to SDK developers who don't want to create a new framework target for each platform, when the code is largely identical. This may be possible to do with apps by defining things like `WRAPPER_EXTENSION` (and probably many other settings), but it almost certainly would break Xcode's General and Capabilities panels for that target. While I encourage this practice for frameworks/libraries to avoid the explosion of MyLib-iOS/MyLib-TV/MyLib-Watch/MyLib-macOS targets, I would discourage it for apps. They are different things, and to do it for frameworks requires less twiddling with obscure settings. It probably also breaks 

If possible, use [xcconfigs](https://pewpewthespells.com/blog/xcconfig_guide.html). Even if you don't move all of the build settings definitions out of the GUI and into them, just defining the important different I outlined above can help a lot. This allows you to invoke `xcodebuild` with the same scheme/target and a different xcconfig per app variant you want to build with the `-xcconfig` option.
