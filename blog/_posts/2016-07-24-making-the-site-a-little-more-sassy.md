---
title: Making the site a little more SASSy
date: 2016-07-24
layout: post
abstract: Why I decided to use SASS to manage the site's CSS.
author: Andrew McKnight
author-email: andrew@tworingsoft.com
tags: web
---

I refactored the webpages here a bit to make room for this blog, and thus also the stylesheet code I've written so far. I remember hearing about the CSS preprocessor <a href="http://sass-lang.com" target="_blank">SASS</a> a year or two ago when I didn't need it, as I was developing solely for iOS. I had a feeling it would facilitate organizing my stylesheets modularly and keeping them DRY, so I resolved to learn the basics before moving forward with the refactor. I'm very glad I did!

I learned CSS just after version 2 was released, and in all the time since have become well acquainted with the mess it can turn into if you aren't careful. Even with care, though, CSS lacks some basic constructs that would make code much easier to maintain. Before turning to SASS, I even Googled a few things I wanted just to make sure CSS couldn't do them on its own in some dark corner I didn't know about:

- Value storage/retrieval, e.g. variables
- Reference of previous definitions
- Modular organization and importing of stylesheets*

<span class="footnote">*CSS has importing, but it generates additional network requests. The SASS preprocessor composes everything for you to commit and serve as one file.</span>

SASS supports all of these things, making me a happy coder again in web-land :) Now I have a stylesheet per page or page type, which inherit from various base layers. Those base layers have definitions for abstract element types that are extended by classes with specific names appropriate for the related web page.

One cool thing I learned about is the mapping file generation, which helps browser web inspectors to find the original .scss or .sass file line that generated the CSS ultimately used to render the page. I even found a little trick on my own, playing in Safari's Web Inspector: if you ⌘-hover over the inspector's file/line .scss/.sass hyperlink, it will toggle to the SASS-compiled .css file/line instead:

{% include 
	blog-post-image.html 
	source="sass-vs-css-web-inspector-link.png" 
	alt="Safari's Web Inspector showing a link to the relevant SASS source (left) and the compiled CSS file (right) when ⌘-hovering." %}

Overall, I'm happy with my decision to switch the site's stylesheets to SASS, and I'm happy I was able to get up and running with it so quickly. I'm sure it will make it super easy to tweak the styles for different screen sizes on phones and tablets, the piece of work I'm taking on next for the site, and also something I haven't done before.
