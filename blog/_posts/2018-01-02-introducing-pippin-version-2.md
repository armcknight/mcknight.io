---
title: Announcing Pippin Version 2
date: 2018-01-02
layout: post
abstract: Highlighting some of the new features in the first major update to Pippin.
author: Andrew McKnight
author-email: andrew@tworingsoft.com
tags: ios products swift
---

[Pippin](https://github.com/tworingsoft/pippin) is still evolving quickly alongside some of the apps I'm working on, and I'm starting off this new year with version 2. It contains a lot of bug fixes and tweaks, but the addition of some new Core protocols are what I'm most interested in.

# Alerter

Every app is going to need a way to display errors or other timely information (or even encourage users with a pat on the back). Introducing a protocol to do so enables other parts of Pippin to show an alert should the need arise, and for consuming apps to use and switch alerting solutions without changing callsites. An adapter to [SwiftMessages](https://github.com/SwiftKickMobile/SwiftMessages) is provided as well.

# Fonts

This is a foray into describing the look and feel of an app in a general way. It is used in the InfoViewController, and could open up more reusable UI to be delivered in Pippin. Because UIAppearance is already a declarative API, it isn't clear to me if it can or should be abstracted in a useful way at this time.

# InAppPurchaseVendor

If you want any return on the investment of time that goes into developing an app, then you need a way to license it. One way to do that is to offer purchases of things within your app itself. Usually a server is involved that provides the details of the products, and which ones the user has already purchased; this protocol describes the operations to get those details.

# Environment

As a bonus, there's also a struct that contains references for all the Core protocols. So, instead of declaring properties and parameters to pass around all the different things, you can reference one struct. For now, other Core protocols will retain their individual references to others instead of using the Environment struct–optionality needs to be reworked for that to happen.

# Core Evolution

Pippin Core now has protocols for the following app components:

- Alerting
- Appearance
- Bug Reporting
- Crash Reporting
- In-app Debugging
- Licensing
- Logging
- Data Modeling

Check it out, and please help build it up together with me on [GitHub](https://github.com/tworingsoft/pippin)!


