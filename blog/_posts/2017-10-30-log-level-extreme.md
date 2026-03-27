---
title: "Log Level: Extreme"
date: 2017-10-30
layout: post
abstract: A brief survey of log level concepts in the iOS community and elsewhere.
thumbnail: its-log.png
author: Andrew McKnight
author-email: andrew@tworingsoft.com
tags: ios
---

I recently updated my dependency on the excellent [XCGLogger](https://github.com/DaveWoodCom/XCGLogger) and noticed that in the jump from major version 4 to 6, a new log level appeared: `SEVERE`. Now, I already had a hard time when deciding between certain log levels for certain situations. The first rule in SOLID, *separation of concerns*, lends a helping hand by contextualizing our logs instead of overloading the spectrum of priority.

# It's Log™!

XCGLogger, and [CocoaLumberjack](https://github.com/CocoaLumberjack/CocoaLumberjack) before it, had 5 levels: verbose, debug, info, warn and error. Here are some loose rules I have for how to choose which level to use:

- `VERBOSE`: outputting the values of variables and large data structures.
- `DEBUG`: function invocations to trace execution, additional context in hairy routines, maybe outputting values.
- `INFO`: general events describing usage, e.g. "navigated to such and such screen" or "pressed such and such button".
- `WARN`: execution has left the happy path, but code exists to recover gracefully so that the app can proceed in a previous good state with minimal UX detour (e.g. showing the user a dialog).
- `ERROR`: a problem that will cause data loss, UX breakage, or otherwise require user intervention up to a forced relaunch of the application. I like to know about these early and aggregate them, so I use Fabric's [nonfatal error reporting](https://docs.fabric.io/apple/crashlytics/logged-errors.html) as part of logging at this level.

That being said, I have found exceptions to every rule, and often have trouble deciding which level to use. Usually though, the best indicator is how fast you're able to sift through your own logs–or more painfully, what you're missing.

# Level playing field, slippery slopes

I don't think I'm alone in my confusion. All sorts of [blog](http://thejoyofcode.com/Logging_Levels_and_how_to_use_them.aspx) [posts](http://www.masterzen.fr/2013/01/13/the-10-commandments-of-logging/) have been [written](http://blogs.perl.org/users/preaction/2017/03/choosing-a-log-level.html) on the subject, outlining the author's preferences and rules just as I have above. Of course, there's plenty of discussion on [Stack](https://stackoverflow.com/questions/7839565/logging-levels-logback-rule-of-thumb-to-assign-log-levels) [Overflow](https://stackoverflow.com/questions/2031163/when-to-use-the-different-log-levels) [too](https://stackoverflow.com/questions/186798/how-to-determine-what-log-level-to-use).

As if it were bad enough trying to choose a log level, not all logging frameworks have the same amount of levels, or call equivalent levels by the same name:

- [Log4J](https://logging.apache.org/log4j/1.2/apidocs/org/apache/log4j/Level.html) has `ALL` instead of `VERBOSE` and an extra level in between that and `DEBUG` called `TRACE`. `ALL` seems redundant in a system where log levels are ranked and you could just choose the most permissive level, so I like `VERBOSE` more here. I do like the idea of `TRACE`, but having to stick it in a rank between `DEBUG` and `VERBOSE` doesn't seem like an easy fit.
- [IBM's WebSphere Application Server](https://www.ibm.com/support/knowledgecenter/en/SSAW57_8.0.0/com.ibm.websphere.nd.doc/info/ae/ae/utrb_loglevel.html) has a table correlating different sets of log levels from different versions of its API. It has an astounding 10 log levels (not including `OFF` and `ALL`), including `FINE`, `FINER` and `FINEST`, and developers can add custom levels. I would YAGNI a few of these into oblivion if I had my way, and instead of custom levels I prefer having individual contexts that can each have its own log level or on/off switch.

# The log stands alone

Individual contexts help relieve the need for more and more log levels. Adding levels seems like an attempt to cut through high amounts of noise to get to what's really important. We want to minimize log size on disk while capturing essential information. Moving away from a monolithic log helps more here than adding log levels: it affords much more flexibility without adding more cognitive overhead at each call site.

In [Trgnmtry](https://itunes.apple.com/us/app/trgnmtry/id1146667288?ls=1&mt=8), I had a need to log the CGPoint of a touch as it was dragging around the screen. This output a large amount of information to the log. At first I debated myself whether to log these at debug or verbose levels, but then it occurred to me that I could log them independently, using a different instance of my logging class. Now if I need to see those logs again I can flip them on and off independently without worrying about other information I might suppress or unleash.

# Severely svelte

For now, I'm not spending time working in a new log level. Hopefully it's helping folks out there instead of making things less clear. At least for now they won't have to muck with creating customizations, which would require way more magical Swift code to write with type safety.