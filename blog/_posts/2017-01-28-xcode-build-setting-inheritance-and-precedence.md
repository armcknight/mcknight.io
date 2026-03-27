---
title: Xcode Build Setting Inheritance and Precedence
date: 2017-01-28
layout: post
abstract: Straightening out the tangled web of relationships in the world of Xcode build configuration.
thumbnail: build-setting-inheritance.png
author: Andrew McKnight
author-email: andrew@tworingsoft.com
tags: ios xcode
---

For probably the first year or two I developed apps for iOS, I stayed as far away from the build settings area as I could. I had plenty to focus on learning the Cocoa APIs. Xcode's configuration system is daunting in its power and flexibility, and anyways it provides you with a good enough set of defaults and migrates you on new releases to keep you running correctly.

A small toy app might get by this way, but serious projects need to pay careful attention to how they build their products. With a sufficiently complicated product family, build pipeline and artifact/dependency graph, maintaining the build system can become a full time job. Some [great](http://szulctomasz.com/2015/11/14/xcode-xcconfig-files-for-maintaining-targets-configurations.html) [articles](https://pewpewthespells.com/blog/xcconfig_guide.html) [exist](http://www.jontolof.com/cocoa/using-xcconfig-files-for-you-xcode-project/) that detail the [build settings](https://pewpewthespells.com/blog/buildsettings.html) Xcode offers and ways to keep your ecosystem consistent and maintainable. While I was at Fabric, we open sourced our collection of Xcconfigs: [FABConfig](https://github.com/twitter-fabric/FABConfig). You can find [similar repos](https://github.com/jspahrsummers/xcconfigs) on GitHub, and I've even find a nice [tool](https://jamesdempsey.net/2015/01/31/generating-xcode-build-configuration-files-with-buildsettingextractor-xcodeproj-to-xcconfig/) to extract Xcconfigs from Xcode projects.

# Complex Configuration Compositions

Much of Xcode's build system's flexibility comes from composition–you can use both Xcconfigs and the Build Settings area, and `#include` Xcconfigs into others. Dynamic setting expansion and platform selectors enables automatic resolution of settings based on environment or target details. Settings can be `$(inherited)` from multiple levels of granularity and overridden by target precedence. Xcode projects have _Configurations_ defining entirely parallel sets of settings. 

Inheritance and precedence have their own rules in Xcode, and the complex relationships arising from all the composition methods make it tough to confidently change a setting without inadvertently propogating unwanted changes elsewhere. As a concrete example, Cocoapods will inject Xcconfigs into your project, which can be inadvertently overridden in the Target column of the Build Settings editor. 

## Inheritance

The special selector `$(inherited)` brings in all settings resolved at the next highest level in the build setting graph. There are three main inheritance "trunks" to consider:

- Xcode defaults -> Project -> Target
- Project -> Configuration -> Platform
- Target -> Configuration -> Platform

This does not define a tree, however. Target-level Platform and Configuration settings can inherit from two parents, as seen in the diagram, forming an acyclic graph. I think of the first trunk as linear, and the second and third I think of as transposable from Project- to Target-level: each level of the Project trunk influences its dual in the Target trunk. Also keep in mind that each level in Xcode's Build Settings editor inherits from the same setting in the corresponding Xcconfig.

{% include 
	blog-post-image.html 
	source="build-setting-inheritance.png" 
	alt="The acyclic inheritance graph for build settings."
	narrow="true" %}

In the below screenshot, you can see some build settings that have been defined in both the Build Settings editor and Xcconfig files, with settings defined at top-, configuration- and platform-levels. Each cell in the matrix defines just one value after inheriting. For instance, the Xcconfig version of the Project-level macOS-specific setting is defined as `$(inherited) XcPb`, and the Build Settings editor version of the Target-level iOS-specific setting is defined as `$(inherited) Tf`. When you look at the Resolved column, you can see how inheritance has propogated values down the line.

{% include 
	blog-post-image.html 
	source="build-setting-inheritance-case-study.png" 
	alt="An example using inheritance." %}

_Note that in this example, I purposely left `$(inherited)` off of the Xcconfig version of the top-Project-level setting, so as not to bring a bunch of noise into the example of the architectures list repeating over and over._

## Precedence

Precedence governs what settings can _override_ those from other levels. It's a simple linear progression, starting from Xcode defaults down to Target-level. An easy rule of thumb is to remember that settings defined in Xcode's Build Settings editor always override the settings from any Xcconfig set for that same level. With "Levels" selected in the Build Settings editor, precedence flows from right to left.

{% include 
	blog-post-image.html 
	source="build-setting-precedence.png" 
	alt="The linear precedence progression for build settings." %}

The screenshot below shows essentially the same setup as the one used to demostrate inheritance–the difference being that there's no inheritance! Each cell has the same value as its counterpart in the inheritance-based version, with the `$(inherited)` selector removed. So, the same cells called out above now have the values `XcPb` and `Tf`, respectively. The leftmost values win out due to precedence rules.

{% include 
	blog-post-image.html 
	source="build-setting-precedence-case-study.png" 
	alt="An example using precedence." %}

# Practice Makes Perfect

These simple examples demostrate the rules, but in real life things get much more complicated. Don't be afraid to jump into your project's build settings, and learn what they do. You many find you can greatly simplify some aspects of your build pipeline, and eliminate a few bugs on the way. Download the example projects demonstrating [inheritance](/blog/xcodeproj/2017-01-28-xcode-build-setting-inheritance-and-precedence/build-setting-inheritance-demo.zip) and [precedence](/blog/xcodeproj/2017-01-28-xcode-build-setting-inheritance-and-precedence/build-setting-precedence-demo.zip) used to generate the screenshots and experiment with these rules in the powerful compositional model of Xcode build settings!