---
title: Snapping Angles and Fuzzy Binary Search
date: 2017-03-16
layout: post
abstract: Implementing a variant of the binary search algorithm to find nearest interval angles on the unit circle.
author: Andrew McKnight
author-email: andrew@tworingsoft.com
tags: ios algorithms
---

[Trgnmtry 1.2 is out now on the Apple App Store!](https://itunes.apple.com/us/app/trgnmtry/id1146667288?mt=8) I was hoping it'd make it through review on π day... c'est la vie.

This release introduces a new feature: snapping to angle intervals. Without it, the angle changes continuously as you drag your finger around the unit circle. If you enable snapping to 45° intervals, for example, then as you drag your finger, the closest multiple of 45° is draw. 

The routine that decides the closest angle went through a few revisions.

# First attempt

First, I tried writing it specifically for a circle, knowing the range could be constrained to 360°. It did only draw angles on the appropriate intervals, but it didn't "snap" to the next one at the right time. It should snap back and forth at the midpoint between to allowed angles, but this logic didn't snap until you dragged all the way to the next interval. (Interestingly, the correct behavior was displayed in exactly one quadrant: the fourth.)

<table border="0">
	<tr>
		<td>
			{% include
				blog-post-video.html
				source="original-angle-snapping-small.m4v" %}
		</td>
		<td>
{% include gist-embed.html url="https://gist.github.com/armcknight/1fc2b992607093e8a6cbb698b6ad8003" %}
		</td>
	</tr>
</table>

# Second attempt

I wound up finding a better solution while implementing the custom input view to select a snapping angle. For this iteration of the feature, I only allow a snapping angle that evenly divides 360, so I just hardcoded the array of all such angles in [0, 360]. The input mechanism is a UISlider, so I need to map its float value to a value in this array. I wound up writing `indexOfClosestSorted` as an extension on Array that produces the index of the element with the closest value, seen below.

It turns out that I can use the very same function to snap angles. Instead of the hardcoded array of possible snapping angles, I create an array, given a selected snapping angle, of all the multiples of that angle in [0, 360]. Then it's just a matter of calling `indexOfClosestSorted`.

<table border="0">
	<tr>
		<td>
			{% include
				blog-post-video.html
				source="fixed-angle-snapping-small.m4v" %}
		</td>
		<td>
{% include gist-embed.html url="https://gist.github.com/armcknight/b07f6b01b1e01bb853925fd122a9ffad" %}
		</td>
	</tr>
</table>

# Bonus points

This works just fine for the purposes of snapping integer angles on the unit circle, but `indexOfClosestSorted` is linear time. Also note that it expects the array it's searching to be sorted. What's another search algorithm that operates on sorted lists? [Binary search!](https://github.com/raywenderlich/swift-algorithm-club/tree/master/Binary%20Search) Normally, binary search returns either the location of the query in the array, or reports that it doesn't exist. In our case, we aren't searching for the exact value, just the *closest* one: a fuzzy binary search. The terminating and recursion conditions are slightly different, and we're guaranteed to always get a result. Now we have a logtime search, giving us a (probably imperceptible, at Trgnmtry's scale) performance boost for drawing. See if you can outrun it!

{% include gist-embed.html url="https://gist.github.com/armcknight/a9815424db01d37e51d76a823059db9e" %}

`fuzzyBinarySearchRecursive` extends any `Array` containing `Strideable` elements, which includes both integer and floating point types. It has some nice defaults: much of the time you'll probably want to search an entire array, which you can do with the invocation `myArray.fuzzyBinarySearchRecursive(query: 1000)`–no need to specify the search must take place between the indices `0` and `myArray.count - 1`. It's under testing now at [https://github.com/TwoRingSoft/shared-utils](https://github.com/TwoRingSoft/shared-utils)!