blog post:

Always In, Always On

We use Okta SSO at work, gated behind a Yubikey, and that is how we log into GitHub. Security, good!

Now, I only need to authenticate with Okta once per day. I don't need the Yubikey for anything else. So, I don't use one of their USB-C Nano models that you leave in your laptop. I used to, but I noticed appreciable battery life degradation.

So I have a Yubikey 5C I keep on a keychain, as well as a USB-A model I keep in a USB hub plugged into a KVM in my office, all right between the two halves of my split keyboard–this setup provides easy access to any computer controlled by the KVM (currently three).

But sometimes I'm mobile, and don't have my keychain on me. Or I'm in my kitchen, and my keychain is downstairs. First world problems, I know, but sometimes I'm in flow and don't want to break it by going for a walk.

Like when I need to check something in one of my GitHub PRs. Now, our product is open source, so most of our code is in public repos. But because we have Okta SSO enabled on the repo, if I'm logged into GitHub when I try to view our list of open PRs, I have to fetch my Yubikey to authenticate via Okta as well:

￼

Or, I can _completely log out of GitHub_. Then I can see the list of PRs and see what they're doing.

I'm reasonably sure it's actually only protecting privileged workflows in GitHub Actions in our repo. I've written in to GitHub support in a few different ways asking that the SSO auth wall only be presented when actually running one of those workflows, but this isn't high priority stuff them.

So by adhering to a particular security policy and provider, I actually get a worse experience as an employee than someone that doesn't even have a GitHub account. This reminds of when I realized that jumping through the extra hoops for TSA pre-check brought me back to the same experience of airport security that's already the sole experience in many other places I would travel to after getting it.

The moral of the story is: if your Yubikey isn't always plugged in, you're going to run into issues.

---

For reasons, I use a Verizon mobile 5G hotspot for internet access at home while I'm working. (Reasons: we live in a subdevelopment in Fairbanks, AK that has no broadband offerings, and my last trial with Starlink about 1.5 years ago was abysmal, both in actual service, and also customer support).

Now, I usually keep that hotspot locked down for work only. It has a data cap, but I can stay well under it, even with video conferencing and downloading large IDE/OS updates.

But recently, my wife lost her iPhone on vacation, so while we waited for a replacement after returning home, I let her iPad on the work wifi so she could carry on her usual correspondence. This also meant streaming some shows, which topped out our data cap only halfway through the billing cycle. So we're stuck on 3G speeds for the next couple weeks. Hooray.

Now, I'm not a stranger to 3G speeds. As a developer, most of my work is just uploading and downloading text, which doesn't need state of the art speeds to achieve low latencies. For four years I worked from the road and in a dry cabin tethered to my iPhone, which is all 3G speed–except for the aforementioned IDE updates, which I'd go to a cafe to download while grabbing a coffee–shoutout to [Venue Fairbanks](https://www.instagram.com/venuefairbanks), [Little Owl Cafe](https://littleowlak.com), [The Roast](https://slvroast.com) and [Montana Coffee Traders](https://coffeetraders.com)... just my regular spots among even more chance ones here and there!

So mostly I'm fine. But today is Monday, and I really wanted to catch up on *Slack* messages from the weekend. And unfortunately, Slack's UI either won't load at all, sometimes eventually giving me an "offline" message, or it will load old state, but never actually update with the latest messages. (At this point, I could switch over to the Slack iOS app for my mobile 5G connection, but my Yubikey 5C's NFC, for some reason, doesn't play nicely with my iPhone, so I haven't logged into my work Slack on my phone for 2 years... honestly, not a bad situation!)

And also, I had a work meeting invitation waiting for me, and wanted to ask for a slightly earlier time slot. Logging into the *Google Calendar* web UI took over a minute, and every button click, including an "X" in a popup, either also took minutes or just didn't work at all, leaving weird artifacts throughout the UI. Speaking of meetings, for the longest time, I've only used the Google Meet iOS app to join video calls. For the longest time it was much better on battery life than using it in the browser on a laptop, and it didn't force me to download Chrome or Firefox solely for this purpose.

￼
(Google Calendar took about 1 minute to fully load to a functional state)

￼

(Slack took 1.3 minutes just to load the list of instances I can get to.)

￼

(Actually trying to load the work slack never even worked, it timed out after 5 minutes.)

I might prefer Safari as my browser, but Apple's no darling here either. Let's talk about *Swift Package Manager* for a minute. Every time I change branches, it wants to go back out to the internet to download dependencies. Most of the time I have already downloaded the code/artifacts needed, but it insists on making the network requests anyways. So, now I can't even compile and run a project that I should have no problems with. SPM has become Gatekeeper for programming.

*Notion*, our knowledge base at work, refuses to show me its locally cached data or even let me write a new note until I log in again. I've been writing things down in Stickies.app, thank goodness that doesn't require a network connection to function.

I get it. This is my fault for living in the last frontier and relying on shaky Internet service, and not managing it very well this month.

But, meanwhile, I also lost my credit card on our vacation, and ordered a new one with a new number. My old one was the auto-renew CC on file with *Fastmail*, and the renewal happened to fall on a date in between me cancelling the old one and receiving the new one, so it failed. When I went to update my payment info, the inbox loaded instantaneously after login, and I was in and out in about a minute after successfully getting billing back on track.

So it's not _just me_.

According to Tracxn, Notion has raised $353 million dollars in 6 funding rounds from 44 investors. Slack market capitalization: $26.51 billion. Google market capitalization: $1.84 trillion. Apple market capitalization: $2.72 trillion. There are only 7 countries on earth with a GDP greater than Apple's market cap, and 5 of them have nuclear weapons programs. I feel confident in asserting that the effort to efficiently deliver data over the wire, and design products that are robust against network intermittency, is less than that required to develop and maintain nukes.

I couldn't easily find financials for Fastmail, but I give them $50 a year and see no reason to stop any time soon.

The moral of this story is: if you're not always on a high speed Internet connection, you're going to run into issues.

---

But does it have to be that way?

Do I think I am representative of any significant portion of the user base of these products? Of course not, especially in the Internet speed case. Not many developers around Fairbanks, compared to Silicon Valley.

Do I think that if these companies built with the performance and UX in mind that would deliver a good experience to me, that the entire system would benefit? Definitely.

It reminds me of [2G Tuesdays at Facebook](https://www.theverge.com/2015/10/28/9625062/facebook-2g-tuesdays-slow-internet-developing-world). Once upon a time, companies cared about the bits they were pushing through the wire. Once upon a time, companies sweated the UX details–or am I just retconning all this? Remember Google Mail Basic HTML? Remember old.reddit.com? We should get back to that mindset as an industry, and provide more of it.
