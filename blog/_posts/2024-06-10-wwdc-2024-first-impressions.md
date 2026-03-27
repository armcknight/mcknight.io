---
title: "WWDC 2024 First Impressions"
date: 2024-06-10
layout: post
abstract: "First thoughts after watching the 2024 WWDC Keynote and Platforms State of the Union addresses."
author: Andrew McKnight
tags: apple wwdc
---

Always a fun day, the first day of Apple's yearly WWDC! So much to get excited and inspired about. Here are my thoughts after watching the Keynote and Platforms SOTU.

# Some appetizers

- math notes and calculator, solving handwritten expressions and drawing graphs. I love math, and am excited for how this can help teach it, looking ahead just a few years until I'm helping my own child. I have long used Grapher.app on macOS (alongside Matlab, which of course I lost access to once leaving university), as well as LaTeX for its math typesetting. I also enjoy the graphical output shown in Swift playgrounds alongside a function to show how the output changes with input for numerical types. In fact, I had just brought that up with my watch party right before they showed it in the calculator demo!
- iPhone screencasting to and control from a Mac; at first I thought it was a neat demo, but I can't think of any serious use cases yet. But I can imagine potential futures where macOS/iOS have melded into one (which I love to [engage in](https://mcknight.io/blog/2018/04/16/reach-out-and-touch-faith.html), and the software doesn't draw such a hard line between the devices any longer. If that were to happen, this would be another step on the way there, along with Handoff, Continuity and Universal Control.
- new handwriting improvements, like how you can reflow paragraphs of handwritten text. Need to try to see if the comic-sans-ish "fixed" handwriting is uncanny valley; the idea of it seemed that way to me on first blush.
- Messages tapback improvements, satellite support and E2EE
- password app; I still pay for 1Password and have held off on Passkeys and other passwordless offerings coming out. But I'm interested to try this.
- downloadable topo maps; between that and satellite Messages, they're continuing to close the gap with Garmin InReach capabilities.
- new screenless/tapless gestures on watch/airpods

# Apple Intelligence

Of course it's huge that Apple is jumping into the LLM game, and they seem to be doing it with both feet now.

Being able to execute interactions with voice command that would normally take long series of clunky taps and gestures will be a huge speed boost to accomplishing a desired task, and being able to move on with our life... or just the next in a long queue of tasks to perform 😆 (Side note on a memory that just popped in my head: a long time ago I brought up how much I would prefer a vocal UI for the speed benefit, but people rightly stated they'd prefer not to do that on a train, e.g., or to be on a train while everyone else is doing that. And so it was interesting that Apple are also now offering a textual interface to Siri!)

---

_watches the Platforms State of the Union_

OK, so some more technical details...

## Apple Intelligence, take 2

- specialization: fine tuning for different tasks or characteristics, to train separate models
- "adapters": small collections of model weights that can be overlayed onto a foundation model and swapped as needed
- model parameter compression: quantizing a 16bit model parameter down to 4bits without loss of model quality
- inference perf: speculative decoding, context pruning, group query attention
- similar approach with a diffusion model for generating images

private cloud compute
- new OS, without some things like persistent storage
- removed some mgmt utilities, like secure shell
- secure enclave, secure boot, trusted execution monitor, attestation
- e2ee to server side
- publicly accessible images of server builds for researcher audit

Apple's been working on anonymized learning for a long time. For instance, check out their materials on [local differential privacy](https://machinelearning.apple.com/research/learning-with-privacy-at-scale) (although I'm not sure if this is still relevant).

## Xcode

- Predictive Completion: GitHub Copilot in Xcode. I like the way ⌥ works with the predictions to choose different things
- Swift Assist is a leap beyond copilot-style programming
    - This is something I've been dreaming of for a long time! I first wrote about it in "Metaprogramming" in [Programming: 20 Years In - Metaprogramming](https://mcknight.io/blog/2018/02/07/programming-20-years-in.html#metaprogramming) but I've definitely thought about it much longer. Can't wait to try this!

## Swift Testing

I like the parameterized test feature, which I've previously built in Objective-C. Can't wait to try it in Swift, along with the the organizational and behavioral features.

# Conclusion

Thinking about their OSes, everything up to this point feels foundational for what is about to happen with AI integration into such ubiquitous tools as desktop and mobile computers. The App Store is well past the inflection point on its S-curve, but it's built out an incredibly wide area ripe with integration points, and Apple are poised to switch tracks to a new S-curve and get back on a positive second derivative.

It feels like we're getting closer to having an executive assistant in each of our pockets. At least from the admittedly polished/rehearsed demos, it looks like talking to someone that is holding your phone, and telling them what you need done, and them being able to make it happen with the tools available almost as fast as you can think.

As a developer, I'm excited to see how not only the consumer-side stuff works, but also the developer tooling, and how much more I might be able to get done! If that works for everyone, then maybe the software industry can eek out a bit more performance for the next while, and get things to even better states, faster, with less effort.

# PS

It's a tired cliché at this point, but whenever Apple announce something in an event like WWDC, people love to point out that "they've been able to do X on Y for years!", and I just found this Steve Jobs video on "the difference between a great idea and a great product": [https://www.youtube.com/watch?v=sm1msysj5lw](https://www.youtube.com/watch?v=sm1msysj5lw).
