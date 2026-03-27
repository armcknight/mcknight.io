---
title: "The Art of Source Control, Part 1: Organizing Codebases"
date: 2017-01-14
layout: post
abstract: Outlining some best practices for organizing a codebase.
author: Andrew McKnight
author-email: andrew@tworingsoft.com
tags: git
---

Much of git is mechanical and deterministic, simply tracking differences in text files. To me, this falls under the mathematical/engineering/scientific aspect of the concept. But, it is a tool used by humans, and each human will use it slightly (or vastly) differently. Finding the best practices and balancing the many powerful methods are the aspects I view as an art form. There's no one right way to do anything, and you can make it as simple or as complicated as you like. Today I'm examining the decisions to make around how to even organize code.

# Location, location, location
Let's say I have an SDK called `PlugKit`. It's a new way for business owners to market and advertise their products in iOS apps. Developers can integrate just the eponymous data/networking component to completely customize how "Plugs" are displayed to their users. We also offer some prefab views available by optionally bringing in `PlugKit-UI`, and there's a demo project used as a reference implementation as well as inspiration.

How should I organize the code for these products in Git? Should everything go in one repository? Should each of the three components get their own? [You've](http://gregoryszorc.com/blog/2014/09/09/on-monolithic-repositories/) probably read [many](http://cacm.acm.org/magazines/2016/7/204032-why-google-stores-billions-of-lines-of-code-in-a-single-repository/fulltext) [articles](https://www.bitkeeper.org/BK_Nested_White_Paper.pdf) [already](https://developer.atlassian.com/blog/2015/10/monorepos-in-git/) [on](http://lists.llvm.org/pipermail/llvm-dev/2016-July/102602.html) [the](https://medium.com/@pejvan/monorepos-85e608d43b57#.tupnuwxqu) [pros](http://blog.shippable.com/our-journey-to-microservices-and-a-mono-repository) and [cons](https://www.thoughtworks.com/insights/blog/architecting-continuous-delivery) of [monorepos](http://danluu.com/monorepo/)-it's one of the great developer flame wars, up there with tabs versus spaces and functional versus OO programming. You probably already have your mind made up. What I want to do here is demonstrate some of the most basic processes I use most frequently for each possibility.

I've constructed an example of each strategy, and placed them into the directories `PlugKit-iOS-A` and `-B`. One is a monorepo with a subdirectory containing the code for each component. The other is a directory containing each of the component repositories. Can you tell which is which?

	$> tree
	.
	├── PlugKit-iOS-A
	│   ├── PlugKit
	│   ├── PlugKit-UI
	│   └── PlugKitDemo
	└── PlugKit-iOS-B
	    ├── PlugKit
	    ├── PlugKit-UI
	    └── PlugKitDemo

It seems repository granularity has nothing to do with how your code is organized. Anything you can do in monorepos, you can do with multiple. To me, the big difference between the two is one of workflow.

# Cloning repositories
Yesterday I spilled water on my laptop and fried it. Oops. The good news is that now I have one of those newfangled models with the Slide Strip or whatever it's called. Time to pull down my code so I can get back to work:

**Monorepo:**

	$> git clone git@github.com:armcknight/PlugKit-iOS

**Manyrepos:**

There are many ways you could organize the repos with respect to one another. You could have a flat structure like above, in which case you'd just do:

	$> git clone git@github.com:armcknight/PlugKit
	$> git clone git@github.com:armcknight/PlugKit-UI
	$> git clone git@github.com:armcknight/PlugKitDemo

or perhaps you have your demo app pull in the others as submodule dependencies (similarly for other dependency managers like Cocoapods or Carthage):

	$> git clone git@github.com:armcknight/PlugKitDemo
	$> cd PlugKitDemo
	$> git submodule update --init

which could render

	$> tree
	.
	├── PlugKitDemoCode
	└── Vendor
	    └── PlugKit
	    └── PlugKit-UI

or how about

	$> tree
	.
	└──Vendor
	    └── PlugKit
		    └── Vendor
			    └── PlugKit-UI
			    
Don't forget that `--recursive` flag if you have submodules in your submodules!

# Writing code
So I'm coding up a new feature that hits a new endpoint on the server, and because this is a totally new, paradigm-shifting type of data that's coming down, we need a completely different type of UI to display it. And of course, we want to test a few "real world" scenarios and show how to implement this in our demo app.

**Monorepo:**

	# ... coding/testing/cursing/fixing ...
	$> git commit --all --message "I wrote and committed this all in one go, because I'm awesome"

**Manyrepos:**
	
	# ... coding/testing/cursing/fixing ...
	$> cd PlugKit
	$> git commit --all --message "commit PlugKit changes"
	$> cd ../PlugKit-UI 
	$> git commit --all --message "commit PlugKit-UI changes, taking up PlugKit changes"
	$> cd ../PlugKitDemo
	$> git commit --all --message "commit PlugKitDemo changes, taking up PlugKit and PlugKit-UI changes"
		
# Merging feature branches
After some review and much pedantry, at long last we can merge our code! Woohoo! We use GitHub pull requests to merge the branches in, as well as GitHub issues to track the work we're doing, so we'll want to close those too.

**Monorepo:**

	$> git push
	# go to the PR, press the big green button
	# go to the issue, press the "Close Issue" button 
	$> git pull --ff-only

Heck, these days closing issues may [already be done for you](https://github.com/blog/1506-closing-issues-via-pull-requests)!

**Manyrepos:**

	$> git push
	# open PlugKit PR, press big green button
	$> git pull --ff-only
	$> cd ../PlugKit-UI
	$> git push
	# open PlugKit-UI PR, press big green button
	$> git pull --ff-only
	$> cd ../PlugKitDemo
	$> git push
	# open PlugKitDemo PR, press big green button
	# go to the issue, press the "Close Issue" button
	$> git pull --ff-only

Note that order may matter here. Reviewing the changes between three separate pull requests is also not great.
	
# Simplicity

These are some of the most basic usages of git for a typical developer, and in each case, the more repos you must deal with the more steps each task requires. These examples are simple, but each new repo introduces many new combinations of steps particular to the way you arrange everything. I only covered some basic workflows, but plenty of others are similarly more complicated in manyrepos: git bisect, rebasing to split or squash commits, conflict resolution, or just plain searching for a variable name or string (do you even have all the repos cloned and up to date to search?).

I used to advocate strongly for a separate repo for each individual thing being developed. I used to scoff at [Twitter](https://blog.twitter.com/2014/hello-pants-build) and [Facebook](https://code.facebook.com/posts/218678814984400/scaling-mercurial-at-facebook/) forking git/hg just to cope with their gigantic monorepos (at this point I have to wonder if some thoughtful separation could be done–working with Twitter's monorepo _was_ painfully slow). But, I realize that not only is repo division between "codebases" mostly arbitrary, it's much simpler to keep it together unless absolutely necessary. Either you're working on your fork of git, or you're maintaining automation scripts to handle all the separate repos and hoping you don't make mistakes in the manual sequences (which you will). While I'm always open to the need to split off a new repo for reasons, I'll default to monorepos for now.