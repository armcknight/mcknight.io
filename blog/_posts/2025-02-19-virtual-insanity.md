---
title: Virtual Insanity
date: 2025-02-19
author: Andrew McKnight
layout: post
tags: notfunny
abstract: "A real story about how a dreamy ski day turned into a nightmare."
---
Picture this: I'm out of town on a solo ski trip for the week, working mornings and nights, with a couple hours of turns each midday. (I owe my wife an eternal debt of gratitude for letting me away from home and watching the kid alone!) Yesterday was pretty good skiing, good turns, subpar visibility, but good enough to glimpse the beautiful mountain headwall on the lift ride up. I thought about how lucky I am to be able to do this.

I got back to my hostel mid afternoon and was about to shower up and start the evening grind. My phone rings, it's Alissa calling, so I pick up to ask how our daughter is recovering (she's been throwing up the past two days–did I mention just how much I'm indebted to her?) When I pick up to say hi, I just hear crying and unintelligible words. I immediately fear the worst. Our daughter is lost or dead. My panic drive kicks in, I'm trying to calm her down to find out what's wrong.

And that's when a man's voice comes on the phone: "aight nigga, we can do this the easy way or the hard way, just send me $1,500 dollars is all I'm asking..." This second hit of adrenaline hit so hard that, even as someone that's constantly warning family and friends about different types of scams, it never even occurred to me that that is exactly what was happening to me right now. All I could think about was how to make this person happy so I could ensure my wife and daughter were ok, being hundreds of miles away, totally helpless otherwise.

Sad to say I tried to send money several times, and thankfully the services I used all rejected every attempt, with the scammers adeptly walking me through one workaround after another. Finally the call dropped, my heart sank, I called police. Just as I got out "I need to report an ongoing robbery," the scammer called back from a "no caller ID" number, which I immediately picked up, leaving the police dispatch hanging. But this call was extremely garbled and eventually dropped. I knew something wasn't right given the change in incoming number, so I called my wife back, and she picked up with a "hi hunny! how was skiing?"

I'd just had my first virtual kidnapping experience. A day later and I'm still shook. We were able to nervously chuckle about it afterwards, even though in my paranoia I asked her to lock the doors and maybe spend the night somewhere else.

---

Then my programmer brain started churning. How can this problem be stopped? Phone number spoofing has persisted for decades. I assume many people much smarter than me have tried and failed to solve it.

Ideally you find a solution that eliminates false positives (doesn't filter out real communications, potentially for real emergencies) and false negatives (doesn't let through scammers).

Here are some of the ideas I saw people discussing:

Passwords between loved ones. This can help for a benign case, but I don’t think would've helped in my scenario, where the adrenaline is flowing. False positive: assuming a real occurrence is going on, your loved one may not be in a position to provide the password to the attacker. Imagine they are unconscious. Or that you just piss off the attacker by interrogating them.

Blocking all VOIP calls, since this is the technology used by scammers to spoof caller ID numbers. Even if it were possible through carrier or phone settings, which it’s not today AFAIK, it wouldn’t be good because lots of legitimate phone calls are made with VOIP: false negative.

Call auto-attendants, basically software that can answer all incoming phone calls, and prompt the caller to, for example, press "one" or a random number to continue. You could extend this idea to having actual pin codes, passwords, or second factors like TOTPs or hardware tokens that callers would authenticate with in order to speak to you (or how about a [captcha](https://mcknight.io/blog/2025/01/25/captcha-innovation.html)?). False positive: in the event of an actual attack, your loved one desperately needs help but the attacker can't get to you because they don't have the PIN number. Another false negative: legitimate incoming calls that haven’t already prearranged a password to authenticate with; I could imagine a system that could provision one or request one via alternate means like a push notification from an app or email. And, a false positive edge case: AI software could at least solve the primitive solution of "press X to continue."

Keep the scammer busy on the call while you arrange via text message or email for someone to call the supposed victim to make sure they’re OK. False positive (or negative? I haven't made up my mind on how to classify this one yet), though, where they don’t answer their phone because they’re at work or asleep. This is what happened in the original [Reddit post](https://www.reddit.com/r/Scams/comments/18m0qxe/scammer_spoofed_my_moms_number_saying_he_was/) I found explaining the scam hitting me. There, the scam victim went on to call the police, who showed up at their loved one's home. Really, I should've just texted Alissa's phone while I was on the call with her "number" at the same time. But my best attempt was to text some coworkers so that _they_ could call police to go to my house (which I then worried would cause the attackers to kill someone).

Of course there’s the age old hang up and call back a known number, but even this has a false positive edge case where you piss off a real attacker.

For both of those last two mitigations, there is a dual vector attack, described by this [Hacker News commenter 8 years ago](https://news.ycombinator.com/item?id=12463542), where the scammer can first verify the number they're going to spoof isn't currently picking up their phone.

The reason this scam worked so well on me, I guess, is exactly the fear of the imagined false positive cases. The fear that it was real, and the mitigations I imagined would make it worse. I stepped out of line once, asking how they could assure me that once I paid, they'd let my wife and kid go safely. That of course agitated the scammer, which scared me even more.

The best idea I can come up with independently is to only use Facetime audio calling. I split up important contacts so there are separate copies: one with their phone number, and another with their Apple ID info for Facetime calls. If I ever get a call from the phone number version, I won't answer it; I'll call back on Facetime audio. That can't be spoofed, I think, not yet anyways.

---

I imagine this will only get worse as cheap and capable AI proliferates, making voice cloning available to the masses. Despite not being attacked with a clone of my wife's voice, it's very possible the attackers were foreign, and cloned a voice that sounds like an American gangster rapper (there is a lot to unpack here, given theorized foreign interference with American politics and culture war issues, race baiting, etc etc.) But, I'm convinced there was an operator on the other side that had to dedicate their time to working me. What happens when even that is completely automated? We need to figure out how to get ahead of that scaling issue.

Of course, the real solution is antithetical to forcing each and every user of a telephone to deal with this problem on their own, duplicating the effort in trial and error billions of times over. What should happen is carriers need to do a better job, first and foremost. Barring that, Apple could strengthen the guarantees of genuine phone calls made from iPhones to iPhones, in their iOS operating system.

And also, of course, for the real solution at the network-switching level of phone carriers, the solution is extremely expensive. Which, as I’ve learned as a technology professional, kills that idea dead in the water, because if there’s a just-good-enough solution that causes some people some problems some of the time, but costs way less, that’s absolutely what we're going to ship. We'll improve it later, except we won't, because we need to capture the next market segment with the next goodenough product.

So we’re stuck with the reality of not just 10 obvious spam calls a day, but the occasional hair raising, panic inducing call that forces you to confront your deepest fears.

---

As with every technology, there is a trade-off. Dave Chappelle captured this perfectly, if not insanely crassly, in a standup joke that can be paraphrased in a safe-for-work way as: “does it help more than it hurts?“ or, Homer Simpson's quip about "the cause of, and solution to, all of life's problems." The invention of telephony and information networking absolutely helps immensely, and anyways, it’s probably the only way I would’ve been able to learn about virtual kidnapping at all. If we didn’t have even the telegraph, then we’d all be much dumber for it, and easier targets for the snake oil salesmen that have always existed.

---

All I can do is spread this knowledge to try to prevent the next person from suffering like I did. What’s really humbling about this is that I am one of the preeminent technologists in all my families, and am usually the one sounding the alarm for different types of scams I know about. Yet I was completely unaware of this one that’s been known about for decades, at least. It has variations called the [cartel scam](https://www.reddit.com/r/Scams/comments/1gdkehl/comment/lu2i42a/?utm_source=share&utm_medium=web3x&utm_name=web3xcss&utm_term=1&utm_content=share_button), [hi mom scam](https://www.reddit.com/r/Scams/comments/1avx7t0/beware_hi_mum_scam_is_more_convincing/) and [escort threat scam](https://www.reddit.com/r/Scams/comments/1inco0p/possible_escort_threat_scam/).

Stay safe out there!
