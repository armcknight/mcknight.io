---
title: "Good Morning, iOS!"
date: 2019-03-06
layout: post
abstract: "Brainstorming ways to combine Apple's productivity apps into a bird's-eye-view Today widget: Good Morning!"
author: Andrew McKnight
author-email: andrew@tworingsoft.com
tags: UX apple
---

In my [last](/blog/2019/01/28/tag-everything.html) few [posts](/blog/2019/01/07/new-year-new-task-management.html) I've been talking about how I'm using Apple's productivity apps–Notes, Reminders and Calendar to name a few–and ways I think they could improve. This post is another idea for how to put them together for a bird's eye view of the day ahead: a sort of Good Morning feature in iOS.

# Rise and Shine

In iOS 10, Apple introduced the Bedtime feature, to help us wind down our day early enough for us to get a good night's sleep before our alarm. What I’d like to see next is a more assisted way to start my day once I’ve woken up, after that alarm. 

A good Good Morning sequence would tie the information together in a simple way, like a weather complication or a more condensed form of grouped notifications for things like new messages (email, SMS etc). I don’t use News or Music, but those could probably be included in a tasteful way too.

# Prior Art

There are a lot of partial solutions to what I'd like, but nothing really ties it all together in a good UX. Let's look at them for some inspiration and to see what we can improve.

## Siri

I thought maybe what I want already exists in iOS via Siri. I’m not a Siri power user, so I assume there's a lot it can do that I don't know about. I tried a few queries–here they are with a description of responses I got:

**What am I doing today? (What’s today’s schedule look like? What’s today looking like?)** Calendar events scheduled for today, with calendar colors so you know where its coming from if you have 15 calendars like I do.

**What reminders do I have?** Some subset of reminders, none of which are set for a specific day/time in my case, ungrouped but color-coded. It's a little tough to tell them apart as I have 10 different lists in Reminders, not including “Scheduled”.

**What’s on my TODO list?** Just the items from the last list in my Reminders app, as opposed to the Scheduled list, which I expected.

## Widgets

There’s an “Up Next” widget from Calendar app, which shows the very next non “All Day” event from any calendar–it's a nice top widget to have, and a good step towards what I'm looking for. There's another "Calendar" widget that has a nice event display, but apparently only sticks to the current day; it's empty in my late-night screenshot:

{% include blog-post-image.html source="current-morning-ios.png" narrow="true" alt="A glance at my current Today widgets. I'm writing that blog post!" %}

Worse, the Mail and Calendar widgets can't disappear despite being empty, but might in a more dynamically generated UI like a Good Morning widget.

## Weather Lockscreen

The original inspiration for this post is the lock screen you see when first using your phone after waking up from a Bedtime alarm, if you also have Do Not Disturb scheduled. Note that this is different than the Bedtime Option to enable Do Not Disturb. 

I originally discovered this by accident. It’s not obvious enough to set it up explicitly, doesn’t really do a lot, and isn’t retrievable once dismissed. Moreover, I don’t think jumping right into phone usage when I wake up is the healthiest thing–I’d prefer to do this on my own time.

## Shortcuts

Again, an area where I’m not a power user. But just flipping through the gallery, I saw there’s a “Morning Routine” section. There’s a “Brush Teeth” timer, for instance. I’m sure people have come up with more sophisticated shortcut flows that probably accomplish a lot of what I want.

In the end, I don’t want to fiddle a lot with it. For this specialized yet ubiquitous use case, I think it makes sense for iOS to take the reins and use all the information I've already programmed into the aforementioned apps.

# UI

Primarily I'd like to have a new Today widget, with condensed and expanded versions. Another way to access would be Siri, so you could see everything at any point in time. This would probably be the way I’d prefer to use it, as I’ve slowly been increasing my usage of Siri.

{% include blog-post-image.html source="good-morning-ios.png" narrow="true" alt="A condensed version would show some aggregated information from Apple's productivity apps, along with some main complications that could possibly be user-configurable. An expanded version could have actions and even live-update as you return messages or check off TODOs, to help you get to Good Morning Zero." %}

Things can get noisy quickly. I'd want options to constrain Good Morning entries to messages from communication to specified Contacts entries/groups, or specific Reminders lists or Calendar... you know... calendars. This way, all those helpful automated emails won't spike your numbers and leave you with a long list of things to do.

# Possible next steps

Weekly/Monthly/Yearly outlooks: am I going to need a babysitter this week? Who’s birthdays are teeing up this month? What New Year’s resolutions am I working on? These might be easier to answer with a little structured data and UI similar to the Good Morning widget, which is really a Daily outlook.

That Daily outlook could be more than Good Morning–it could be Tonight, or really just the next 8-12 hours in front of you. Here's hoping something like this is coming up next in iOS 13 🤞🏻
