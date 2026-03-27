---
title: CocoaPods and Custom Build Configurations
date: 2018-02-15
layout: post
abstract: My long journey to set a devpod's SWIFT_OPTIMIZATION_LEVEL, from the podspec's pods_target_xcconfig, to Podfile's post_install and finally arriving at the succinct project.
author: Andrew McKnight
author-email: andrew@tworingsoft.com
tags: ios cocoapods xcode
---

Problem: I have an Xcode project for an app that has many custom build configuations beyond just Debug and Release. That app is being developed together with an SDK, for which we use CocoaPods as its distribution mechanism as well as for devpod setup. In the SDK, I wanted some of these custom configurations to compile with no Swift optimizations so I could debug, while other configurations intended for release should have whole module optimization enabled.

I already knew that I could set build settings from a podspec, but I've never done this _per configuration_. I found this [Stack Overflow answer](https://stackoverflow.com/a/34200599), where unfortunately the author notes that [conditional variable assignment](https://pewpewthespells.com/blog/xcconfig_guide.html#ConditionalVariableAssignment) doesn't work with podspecs' [`pod_target_xcconfig`](https://guides.cocoapods.org/syntax/podspec.html#pod_target_xcconfig). (Check out this GitHub issue on [CocoaPods support for conditional variable assignment](https://github.com/CocoaPods/CocoaPods/issues/7133).)

In my particular case, needing to override `SWIFT_OPTIMIZATION_LEVEL` presents an additional challenge. Contrary to the findings of the SO post, I did see an xcconfig written to `Pods/Target Support Files` with all the configuration-specific settings, and saw it reflected in Xcode's Build Settings GUI editor. Here's the issue: CocoaPods hardcodes the default values for this setting, but writes them to the pbxproj _Target_-level settings, thus [overriding my xcconfig settings](http://tworingsoft.com/blog/2017/01/28/xcode-build-setting-inheritance-and-precedence.html). If they instead wrote it to the _Project_-level, they'd be overridable by anything set in `pod_target_xcconfig`. (See [`PROJECT_DEFAULT_BUILD_SETTINGS`](https://github.com/CocoaPods/Xcodeproj/blob/c39a015920c4c15701c8383aa240b7b3207a4ed9/lib/xcodeproj/constants.rb#L333) and [`COMMON_BUILD_SETTINGS`](https://github.com/CocoaPods/Xcodeproj/blob/c39a015920c4c15701c8383aa240b7b3207a4ed9/lib/xcodeproj/constants.rb#L226-L230) in `constants.rb`, and [project_helper.rb](https://github.com/CocoaPods/Xcodeproj/blob/c39a015920c4c15701c8383aa240b7b3207a4ed9/lib/xcodeproj/project/project_helper.rb#L51) where `COMMON_BUILD_SETTINGS` is accessed via `new_target` -> `configuration_list` -> `common_build_settings`.)

Fortunately, there's the venerable `post_install` hook, where we can modify targets' build settings, just like was once required for [`SWIFT_VERSION`](https://github.com/CocoaPods/CocoaPods/issues/5521) (That workaround has since been obviated with the root specification [`swift_version`](https://guides.cocoapods.org/syntax/podspec.html#swift_version) as of [cocoapods 1.4.0](http://blog.cocoapods.org/CocoaPods-1.4.0/)–ctrl-f 'Swift Version DSL`, it's a ways down. The catch here is that the SDK maintainers must take up this change.).

So, in my Podfile, I wrote the following:

	post_install do |installer|
	    installer.pods_project.targets.each do |target|
	        if target.name == 'MyDevPod'
	            target.build_configurations.each do |config|
	                if config.name == 'My-First-Config'
	                    config.build_settings['SWIFT_OPTIMIZATION_LEVEL'] = '-Onone'
	                elsif config.name == 'My-Second-Config'
	                    config.build_settings['SWIFT_OPTIMIZATION_LEVEL'] = '-Owholemodule'
	                # ...
	                # and so on for the other configurations
	                # ...
	                end
	            end
	        end
	    end
	end

This is also [recommended](https://github.com/CocoaPods/CocoaPods/issues/4439) by a few folks in a discussion in particular about `SWIFT_OPTIMIZATION_LEVEL`. There's even a [plugin](https://github.com/jedlewison/cocoapods-wholemodule). It's certainly a fine solution, and in general the approach enables all sorts of customizations.

But then I found out about the Podfile's [`project` directive with `build_configurations` hash](http://guides.cocoapods.org/syntax/podfile.html#project) (h/t to [mokacoding's article on the subject](http://www.mokacoding.com/blog/cocoapods-and-custom-build-configurations/), which is almost 4 years old now–the only difference being that `xcodeproj` has been renamed to `project`). So, I was able to remove the `post_install` hook in favor of this one-liner at the top of my Podfile:

	project 'MyProject', 'My-First-Config' => :debug, 'My-Second-Config' => :release # and so on for the other configurations
	
This works because CP have coded the desired settings between Debug and Release, so that the `project` `build_configurations` hash maps to the settings I had set using `post_install` previously. I prefer defining these in a first-class Podfile construct like `project` as opposed to a more arbitrary-code solution such as `post_install`.
