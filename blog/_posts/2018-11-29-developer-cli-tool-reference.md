---
title: "Developer CLI tool reference"
date: 2018-11-29
layout: post
abstract: A collection of command line tools I've used on *nix systems.
author: Andrew McKnight
author-email: andrew@tworingsoft.com
tags: tools
---

I've long kept a list of tools to help me brainstorm when I go off to spelunk through a given problem or system. As such, the tools are divided into a few broad categories.

I figured it'd be helpful to publish it here–the goal is to have a living version of this document, so I'll update it as needed from time to time. Feel free to [submit changes to add or improve something](https://github.com/TwoRingSoft/tworingsoft.com/edit/master/blog/_posts/2018-11-29-developer-cli-tool-reference.md)!

> Many of these have an enhanced version in [gnu core utils](https://www.gnu.org/software/coreutils/coreutils.html) (`brew install coreutils`) prefixed with a `g`. If available, it allows for a consistent experience across different *nix systems, as some builtins have slightly different option sets and behavior between OSes, such as Linux versus macOS.

# Binary executables

  - otool
  - lipo 
  - dwarfdump 
  - nm
  - strings
  - dsymutil
  - objdump
  - uuencode/uudecode
  - patch
  - xxd

# Networking

  - scutil
  - ifconfig
  - curl
  - ping
  - traceroute
  - netstat
  - nslookup
  - whois
  - hostname
  - tcpdump
  - ssh
  - ftp
  - scp
  - host
  - telnet (removed from macOS starting with High Sierra)
  - wget†
  - iwlist†
  - iwconfig†
  - ufw†
  - nc*: netcat
  - dsh*: distributed shell, multiple concurrent SSH sessions
  - awscli*: AWS CLI
  - scout2*: AWS security auditing

# System

  - ls
  - file
  - lsof
  - top
  - ps
  - finger
  - fswatch
  - stat/readlink
  - du/df
  - kill
  - killall
  - fuser
  - uname
  - whoami
  - pwd
  - env
  - screen
  - systemctl†
  - service†
  - tree*
  - tmux*: terminal multiplexer; terminal split-pane screen sessions
  - tmuxinator*: script and manage tmux sessions

# Stream processing

  - xargs
  - awk
  - cat
  - echo
  - sed
  - tail
  - head
  - less
  - more
  - cut
  - tee
  - grep
  - jq*: JSON manipulation
  - ag*: The Silver Searcher, a grep alternative

<div class="footnote">
* 3rd party<br/>
† Linux only
</div>
