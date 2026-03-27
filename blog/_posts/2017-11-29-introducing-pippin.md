---
title: Introducing Pippin
date: 2017-11-29
layout: post
abstract: An update and first official version of my Swift app development framework.
author: Andrew McKnight
author-email: andrew@tworingsoft.com
tags: ios products swift
---

Hello. I am an iOS developer. For a while now, I've had a repository of random Swift extensions and helper functions, dubbed "shared-utils." A colleague of mine once remarked how bad the kitchen-sink pattern is in code organization, and it's rung true for me ever since. Recently I renamed "shared-utils" to Pippin, to sound more Apple-y and get away from that utility name, and now today that library is marked as version 1.0.

The biggest change is the organization of the code: a flat list of files became separate tools to scaffold an app or perform specialized flows for accessing video or location, or working with Core Data. (Yes, there are still a ton of "utility" type files, which I swept away under a euphemistic "Extensions" rug). The different collections are all available as separate CocoaPods subspecs (with some necessary dependencies–I use extensions on Foundation in my Core subspec, for instance). Here's the top-level organization:

```
Pippin
    ├── Adapters
    │   ├── *PinpointKit
    │   └── *XCGLogger
    ├── CanIHaz
    │   ├── *AVCaptureDevice
    │   └── *CLLocationManager
    ├── *Core
    │   ├── Bug\ Reporting
    │   ├── Crash\ Reporting
    │   ├── Logging
    │   └── Model
    └── Extensions
        ├── *Foundation
        ├── *UIKit
        └── *WebKit
```

Every directory with an asterisk has a subspec that can be pulled independently. Here are the dependencies:

- Core: Foundation
- PinpointKit: Core
- UIKit: Core, Foundation
- WebKit: Foundation
- XCGLogger: Core

# Pippin Core

There is plenty of cool stuff in the extensions, but the things I really want to focus on are the Core and Adapter subspecs. The idea is to supply protocols that describe major infrastructural components of an app, like bug reporting, crash reporting, logging, data modeling, reading and writing. Things every major app is going to use, but may not implement the same exact way, or, as is my preference, use one of several 3rd party frameworks to avoid reinventing wheels. 

From the standpoint of the developer of my app, all externalities are considered impermanent. So, I write an adapter from a Core protocol to the 3rd party tool I want to use. If that tool should go away or be deemed unworthy at some point, I can write an adapter to a new one or even roll my own, without any change to all the apps utilizing that protocol.

Two adapters are provided already, PinpointKit for bug reporting and XCGLogger for logging. Each subspec describes the dependency on the respective CocoaPod so it's only pulled if used. Ideally, there'd be a collection of adapters to each external framework that exists, but these are the ones I currently use. I also use Crashlytics, but it's a special situation because CocoaPods will not allow you to have transitive dependencies involving static libraries. For now, the Crashlytics adapter class is provided as a separate source file in the repo only, not in any spec. It is up to the consumer to include the actual Crashlytics CocoaPod in their own Podfile and get the adapter class into their project if they want to use it. Hopefully a real Crashlytics adapter can be written once [CocoaPods releases support for static libraries from source](https://github.com/CocoaPods/CocoaPods/pull/6811).

# Smoke Tests

I worried that by splitting up the flat list into hierarchies and then separating its branches into subspecs, I'd discover dependencies between branches. I tested for this by writing a smoke test that would generate a new Xcode project for each subspec (actually, one in both Swift and Objective-C) using [XcodeGen](https://github.com/yonaskolb/XcodeGen), write an appropriate Podfile and install pods, and then just see if it builds. Unsurprisingly, a few things did fail, until I teased out the relationships outlined above and encoded them into the podspec.

# Sauce

It's not perfect. There are some things that don't quite fit into their current spot, like the UIKit extension subspec's dependency on Core, or structs that don't actually extend anything from Apple's API like Build or SemanticVersion. Different subspecs are in various stages of their evolution. There could, of course, be more of everything, including tests. But it's 1.0 today so I can stop emotionally leaving it at 0.0.1 and be more realistic about how changes are evolving the codebase.

Check it out today at [https://github.com/TwoRingSoft/Pippin](https://github.com/TwoRingSoft/Pippin)!
