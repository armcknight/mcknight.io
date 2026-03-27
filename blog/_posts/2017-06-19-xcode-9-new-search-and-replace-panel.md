---
title: Xcode 9's New Find and Replace Panel
date: 2017-06-19
layout: post
abstract: A critique of the new source editors tool's UI and UX.
thumbnail: xcode-side-by-side.png
author: Andrew McKnight
author-email: andrew@tworingsoft.com
tags: UX xcode
---

In Xcode, I make heavy use of the Replace function, both in the source editor (`⌘⌥F`) and the Find navigator (`⇧⌘⌥F`), and much of that use includes regular expression capabilities. At this point I can fly through all the modifier popovers and dropdowns without leaving the home keys. To boot, I've had a lot of practice with it lately due to the complete lack of refactoring support for Swift.

Xcode 9 has a brand new source editor implemented from scratch in Swift, and the Find/Replace panel I've come to know so well also received a makeover. After using it for a few days, I've found what I like about it, and what I'd like to see for the final release. Below is my critique of the UI and UX, in which I've done my best to leave no stone unturned.

## General look and feel

Overall, the new panel composition and design is slick, with both bold and subtle differences from its predecessor. I immediately noticed that it had been changed because I use a dark background in my source editor, and Xcode 9's new Find/Replace panel now respects the selected themes! The differences are extremely subtle between different light and dark themes, though. For instance, in Default, the text fields' background color is RGB(219, 219, 219), whereas with Sunset chosen it is RGB(219, 219, 218)–less than half a percent change in the blue value! Check out the differences, with Xcode 8 on top and 9 on the bottom, with both light and dark themes:

{% include 
	blog-post-image.html 
	source="xcode-side-by-side.png" 
	alt="The Find and Replace panel in Xcode 8 (top) and Xcode 9 (bottom)." %}
	
_Note:_ from now on throughout this post, Xcode 8 screenshots will always have a dark editor background, and Xcode 9 will have a light background.

## The button cluster

The group of buttons on the right is one of the more striking changes in the new version. Before, the Find and Replace fields joined to the buttons immediately to their right, mixing the text fields and buttons in a sort of segmented control. Now, only the buttons are members of the segmented controls, their rounded corners facing those of the text fields underscoring their separation. The buttons are now shorter in height than the text fields, whereas each button is wider than it was in 8. I think at least the previous and next result buttons ("⟨" and "⟩") and replace "All" button could lose some width, maintaining equal overall width between the top and bottom rows.

{% include 
	blog-post-image.html 
	source="right-button-cluster.png" 
	alt="The right button cluster from Xcode 8 (top) and Xcode 9 (bottom)." %}

The difference in margins around the text fields versus the button cluster to the right is a bit jarring to me. In Xcode 8, equal vertical spaces lie between the container edges to the text fields and attached button cluster rows, and between the two text fields and rows of buttons themselves. Since the buttons are now shorter than the text fields in height, the space between the rows of buttons is now twice as much as the space between the text fields, along with leaving unequal spacing to the edges of the container around them. I would prefer the buttons to remain the same height as the text fields.

## Search modes

The first thing that actually stood out to me (besides the obvious difference in design language) were the new case-sensitive and regex search buttons in their new home as the farthest-right accessory views in the Find field. The great news is that what used to take 5 clicks (or arrow/escape/spacebar/return key presses) now only requires one. Unfortunately, they do not respond to keyboard input, or even correctly support tab navigation (radars: [rdar://32829012](http://openradar.appspot.com/radar?id=5032133286428672) and [rdar://32863002](http://openradar.appspot.com/radar?id=4960029375463424)). The following video shows attempting to tab to the case-sensitivity toggle and pressing spacebar (hitting tab to attempt further navigation would likewise insert a tab into the source editor):

{% include
	blog-post-video.html
	source="tab-navigation-xcode-9-beta-search-replace.mp4" %}

The options to restrict results to strings "starting with" and "ending with" the query are gone in Xcode 9. Personally I am fine with this since you can write regular expressions for them, using `^` (start) and `$` (end) [anchors](http://www.regular-expressions.info/anchors.html).

{% include 
	blog-post-image.html 
	source="prefix-and-suffix-search.png" 
	alt="The prefix and suffix search options in the search option popover dropdown." %}

One other thing removed in Xcode 9 is the "Insert Pattern" (`^⌥⌘P`). I personally never used this, but it appears to no longer be available even via the menu bar. If I had to guess, that was a system-wide option that was not carried over to a from-scratch rewrite (a very similar Find/Replace panel exists in TextEdit.app, with the "Insert Pattern" option–but no real regex support).

{% include 
	blog-post-image.html 
	source="insert-pattern.png" 
	alt="The Insert Pattern option in Xcode 8 didn't make it to Xcode 9." %}

## Other buttons and controls

The dropdown to the left of the text fields for "Find" and "Replace" with the ever-present current selection has been removed. This now drops down from the magnifying glass in the Find field's left accessory view, which in Xcode 8 opened the dropdown with all the search options. Not having to display those superfluous labels reclaims some horizontal space in the panel, which I like. The vertical lines in this image show the space saved from Xcode 8 (top) to 9 (bottom).

{% include 
	blog-post-image.html 
	source="magnifying-glass-dropdowns.png" 
	alt="The new magnifying glass dropdown saves space in Xcode 9 (bottom) compared to Xcode 8 (top)." %}

The clear button to the right of the match count label in the Find field has disappeared, which may irk some developers who prefer to point and click in the GUI. To clear the text from the field, one must now double- or triple-click, or click and drag to highlight to select all the text, and press delete. Or, for the terminal lovers, `^A` and `^K` still work too.
	
## Match count label

The count of matches, in the leftmost right accessory view position of the Find text field, previously did not display units-now it affixes "matches". It offsets some space saved by other UI changes, but I think it looks clean and is better than having a random number hanging around. (Always [mind your units](https://www.opticianonline.net/opinion/letter-mind-your-units)!)

{% include 
	blog-post-image.html 
	source="match-count-label.png" 
	alt="The match count in Xcode 8 (top) versus Xcode 9 (bottom)." %}

## Using text selections

Something I didn't even notice until I started pulling apart the two UIs: in versions ≤ 8, holding `⌥` changes the "Replace" button to "All in Selection". Fortunately, it still exists in the menu as "Use Selection for Replace" (`⇧⌘E`), along with it's sibling "Use Selection for Find" (`⌘E`). I always love finding hidden little helpful details like this, so I'm waiting for the chance to use it. Hopefully I remember!

{% include 
	blog-post-image.html 
	source="all-in-selection.png" 
	alt="The All in Selection option for replacement." %}

## Recent searches

Another thing that might irk some folks is the disappearance of the "Recent Searches" list in the old magnifying glass dropdown. I know it has saved me a few times when I had a complicated regex constructed, and then forgot about the system-wide search field behavior in macOS! ⊙▂⊙

## Put a bow on it, 

As it's the first beta release, and especially because this is brand new UI, there are a few rough edges. In addition to the tab-navigation problem, regex replacement currently does not interpolate capture groups [rdar://32827938](http://openradar.appspot.com/radar?id=4928589677985792).

Overall I'm really pleased with the new look and feel and the UX improvements that were made. I think one or two bug fixes there, along with tweaks to margins, would seal the deal for me. But, I'm already happy with the changes, and am excited to use it in its final form in Xcode 9 along with all the [other](http://shashikantjagtap.net/hands-xcuitest-features-xcode-9/) [great](https://venturebeat.com/2017/06/05/apples-xcode-9-finally-allows-ios-app-testing-over-wi-fi/) [new](https://dzone.com/articles/the-marriage-of-github-and-xcode-9) [features](https://iosdeveloperblog.com/xcode-9-new-feature-increase-font-size-keyboard-shortcut-cmd/)!