---
title: Dependency Management Best Practices
date: 2018-01-09
layout: post
abstract: In light of recent news about dependency manager breakages and vulnerabilities, highlighting some steps you can take to protect your dependencies and the projects for which you need them.
author: Andrew McKnight
author-email: andrew@tworingsoft.com
tags: security cocoapods
---

There have been a few unfortunate incidents and revelations in the world of dependency management recently, which present possible (or realized) attack vectors. Some notable examples are [leftpad](http://blog.npmjs.org/post/141577284765/kik-left-pad-and-npm) and a more recent article on [hackernoon](https://hackernoon.com/im-harvesting-credit-card-numbers-and-passwords-from-your-site-here-s-how-9a8cb347c5b5). 

While NPM was the unfortunate victim in both of these cases, the problems of removed packages breaking builds, malicious packages either taking their place or masquerading as real ones with slight typographical differences in naming, or just pulling in unreviewed dependencies are not problems with the tooling. They are PEBKACs, ranging from innocent mistakes to failures to fully harness the power of the tools at hand.

# Do not trust dependencies.

I'm as guilty as anyone of pulling in dependencies without meticulously reviewing every line of code. In most cases you just aren't going to understand it the same way as if you just build it yourself. But that doesn't mean we shouldn't strive to understand those dependencies that we must use. I've gotten better at it and continue to strive for improvement.

# Do not trust that dependencies will always be there.

One thing I've been better about the past few years is to always fork dependencies. How you do you know it will be there the next time you need it? How do you know the maintainers will not rewrite history and remove a release you depended on?

In  circles that use CocoaPods, this comes down to a dogmatic debate over whether or not to check in `Pods/`, [which I do](http://tworingsoft.com/blog/2017/04/12/source-control-management-vs-dependency-management.html). That way, the only thing that matters is whether you can access the project you own–if you can't get to that, it doesn't matter whether you can get your dependencies or not. You aren't doing work.

Forking allows you another layer of control on when you update your dependencies. You can view the code diff when you bring upstream commits into your fork. Then you can update consumers from your fork. 

# Do not trust dependency managers' central stores.

Do you trust that just because you declare a dependency on SomePackage 1.2.3, that it will be there the next time your CI box performs a fresh clone and tries to build? Do you trust that the servers that deliver packages and metadata are up when you need them to be?

Yet another thing CocoaPods allows is to use a [private podspec repo](http://guides.cocoapods.org/making/private-cocoapods.html) to serve the dependencies. If you like control over your dependencies, then this decentralized approach is superior to relying on `trunk`. Admittedly, I have not taken this step yet with my own projects, but it's worth noting for those who haven't tried it. Another thing I have yet to dive deep into is [Carthage](https://github.com/Carthage/Carthage), which is always decentralized.

# Do not trust. Ensure.

I've learned from experience not to trust computers–rather, that people are able to perfectly program them–so I remove as much dependency on them to do the right thing as possible. Instead, exert as much control as is available to you, to ensure that every bit of code you need is available to you at all times, and that it is what you expected.