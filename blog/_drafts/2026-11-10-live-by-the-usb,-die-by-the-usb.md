---
title: Live by the USB, Die by the USB
date: 2026-11-10
author: Andrew McKnight
layout: post
tags: tech hardware
abstract: "I never knew the Universal Serial Bus standard would have such a variety of entrants. Or that this could have real, dangerous consequences."
---
I just started back at work after paternity leave and needed to reconfigure my work space a bit to get my work machine slotted back into my office lab setup. I wasn't anticipating such a hair-pulling endeavor. Here are some of the issues I hit, and things I learned along the way.

First, here's my workstation topology, which I'll be upgrading as a result of this tribulation; I'll publish a new post with the subseqent changes later.

<!--topology-->

<!--/topology-->

My aging Apple Thunderbolt Display's integrated USB port was causing hiccups in the connection for my keyboard and trackpad.

USB A-to-C cables can be unidirectional for data flow, like meant to plug the A side into a computer and the C side into a phone

i have a magic keyboard with touchid plugged into my kvm

if i plug that unidirectional C-to-A cable into my thunderbolt dock (which is connected to my mac mini) at the C end and the A end into the KVM, touchid works

if i substitute it for an A-to-A cable directly into my mac mini, the keyboard still works, but touchid doesn’t

if i then take that C-to-A cable and plug the C end into the keyboard and the A end into that same port on the mac mini, touchid works

but it still can't send a wakeup signal to the laptop, which i like to use in clamshell mode so it can sit out of the way on my desk, upright in a twelvesouth stand

# home charging station

while we're here, let's talk about the other main usage of USB in my home, our family's device charging station

it's currently a USB charging hub with 8 A ports. Some time ago I bought some A-to-C/micro/lightning 3-headed cables to facilitate the variety of devices we need to charge

i'm upgrading this as well
