---
title: Going Back to the Future to test with git-rebase
date: 2016-11-22
layout: post
abstract: Adventures in Git, using rebase to reorder history and automate some testing, too!
author: Andrew McKnight
author-email: andrew@tworingsoft.com
tags: git
---

I recently built up a long list of commits working on a refactor, and just realized that I rewrote a codepath that had some bugs in it. As any good refactorer (refactoror?) does, I tried to get adequate testing in place before refactoring. Unfortunately, this buggy codepath was never tested in the first place, a fact I overlooked until today.

So, I set out to test the code in the past, before I wrote the new code. How could this be? While building an actual time machine would make quite the pleasing pun of "all-time yak shave", luckily for me git already has a facility to do what I want: git-rebase.

First things first, I gotta go back and write a new test. I left my current feature branch (let's call it "topic") and went back to my main branch ("master"). Then I created a new branch "tests", and made some commits writing a test to get that rogue codepath covered. I placed as many constraints as possible on it, capturing the buggy output in test assertions. This way, when I fix the bugs, the tests should break, and I'll update them to pass again later.

OK, great, now we have two diverging branches. This is the first thing git-rebase can help with. I can have it remove my original feature branch from its base in "master" and re-base it onto the head of "tests", so it will look like I wrote that test before doing any feature work. Here's that incantation: `git rebase --onto tests master topic`. The git docs have some diagrams (see the link below) as well as this <a href="https://blog.pivotal.io/labs/labs/git-rebase-onto">blog post from Pivotal Labs</a>.

Now all the commits are in a single history again, whew. But, I had a ton of commits on my original branch, "topic", and some of them modified that buggy codepath, and I can't remember which commits are now breaking that test. (Generally, I like each commit in my history to both be able to build and pass tests–otherwise there should be squashing going on (another use for git-rebase!).) Luckily, git-rebase can help me find the commit. I can have it run my test suite for each commit in my history since branching from master: `git rebase --exec "run-tests.sh"`. Because run-tests.sh exits with a non-zero status if a test fails, the rebase will plop me right into edit mode on the commit that broke the bad tests, so I can make the world right again.

Check out the <a href="https://git-scm.com/docs/git-rebase">git-rebase</a> documentation to find out more about --onto and --exec.