---
title: "Interpreting Apple's Transparency Report"
date: 2019-01-23
layout: post
abstract: Apple recently released their transparency report for government and private party information requests for January through June of 2018, in an updated format including broken out CSVs.
author: Andrew McKnight
author-email: andrew@tworingsoft.com
tags: apple ethics legal data
---

Earlier this month Apple released their [transparency report](https://www.apple.com/legal/transparency/) for January 1 to June 30 of 2018, detailing requests for various types of information from governments and private third parties. They publish the information in a nice web app presentation, PDFs and CSVs... perfect for some number crunching.

> Update: removed a comment about Germany being an outlier in the 4th chart, Requested Device Amount Distribution; I wrote that comment about a different chart and swapped them out without removing the comment!. Also updated FastMath to 2.2.1, as I released a few fixes used while publishing, and a few wording improvements.

# Crunching the Numbers

I focused on requests targeting devices, financial identifiers and account info. There are other types of requests reported, but the formats of the CSVs are different, so I stuck to these for simplicity's sake. They're also the main ones used on Apple's website for detailed country reports. 

For each request type, I'm interested in the number of requests received from each country, the amounts of items requested and the amount of requests honored by Apple. Apple reports those last two as ratios and percentages, respectively. I converted requested item ratios to absolute units to show how many devices or accounts are being sought, and while I use percentage of honored requests as a proxy for request quality, I also convert those to absolute units for side-by-side comparison in each chart showing amounts of requests.

I'm most interested in the number of items requested, as that is the true _impact_ on Apple's users–and the world's citizens. I see the number of requests–and hence the ratio of items per request–as the _efficiency_ of the requesting country. Finally, the percentage of fulfilled requests I use as a proxy for the _quality_ of the requests submitted.

## Device Requests

Here are the top 10 countries, by number of devices across all requests:

{% include blog-post-image.html source="atr-2018h1/requested-devices-top-10.png" narrow="true" mobile_fullwidth="true" %}

For the same 10 countries, here's the breakdown of the amount of requests made, along with the amount of requests that Apple honored:

{% include blog-post-image.html source="atr-2018h1/device-requests-top-10.png" narrow="true" mobile_fullwidth="true" alt="Poland and South Korea submitted a very small amount of device requests, each with a large batch of target devices. Very efficient!" %}

> The number of requests includes updates or resubmissions of earlier requests either rejected or withdrawn. Only a subset of the difference between the number of requests submitted and those honored by Apple may represent some set of devices that were never disclosed.

Here's how the amount of devices those countries request has trended over time:

{% include blog-post-image.html source="atr-2018h1/requested-devices-over-time.png" narrow="true" mobile_fullwidth="true" alt="Poland requested over half a million devices in H2 of 2014! I had to go back and double check the original reports just to make sure. And, they only submitted 30 requests that period." %}

To digest big datasets, I like to look at the [histogram](https://en.wikipedia.org/wiki/Histogram) of the sample values' [z-scores](https://en.wikipedia.org/wiki/Standard_score). This shows the [kurtosis](https://en.wikipedia.org/wiki/Kurtosis) of a population, the "shape" of the data. At a glance, questions about very large populations can be easily answered. Then you can strategize for next steps: is it tightly grouped around the mean, uniformly random, or on a bell curve? Is there a long tail worth considering?

This is the distribution of _all_ countries' requested device amounts, not just the top 10 countries:

{% include blog-post-image.html source="atr-2018h1/requested-device-amount-distribution.png" narrow="true" mobile_fullwidth="true" alt="Mean: ~3.3K devices; standard deviation: ~8.1K devices. Most of the request distributions look like this, meaning most of the countries behave similarly in terms of their requests, with some extreme outliers. Normalizing for other demographic information like GDP or population might change this picture significantly." %}

Again for those top 10 countries by number of devices requested, let's look at the percentage of requests that Apple honored. The _amount_ of requests is shown earlier, in the second chart, but the _percentage_ better demonstrates the quality of a country's requests. Because this is percentage of _requests_, and we don't know details about how many devices were in a given honored or rejected request, it's not possible to deduce how many _devices_ were ultimately uncovered from these numbers. Note that the Y axis starts at 75%, not 0%:

{% include blog-post-image.html source="atr-2018h1/percentage-honored-device-requests-top-10.png" narrow="true" mobile_fullwidth="true" %}

Here's how the quality of those countries' requests have trended over time:

{% include blog-post-image.html source="atr-2018h1/percentage-honored-device-requests-over-time.png" narrow="true" mobile_fullwidth="true" alt="The countries generating the majority of the device requests are tending towards higher quality." %}

Finally, here's how all the countries break down in terms of request quality:

{% include blog-post-image.html source="atr-2018h1/honored-device-request-percentage-distribution.png" narrow="true" mobile_fullwidth="true" alt="Mean: 72.8%; standard deviation: 20%." %}

I got curious about the outliers on that chart: the two countries at -3 standard deviations are Serbia (who requested 1 device in their only request, which was denied) and Mexico (3 devices in 2 requests, both denied). OK, those are pretty non-impactful numbers... let's look at the lowest acceptance rates of device requests:

{% include blog-post-image.html source="atr-2018h1/percentage-honored-device-requests-bottom-10.png" narrow="true" mobile_fullwidth="true" %}

And to get an idea of the impact and efficiency of these countries:

{% include blog-post-image.html source="atr-2018h1/requested-devices-bottom-10.png" narrow="true" mobile_fullwidth="true" %}

<center><font size="80pt">***</font></center>

{% include blog-post-image.html source="atr-2018h1/device-requests-bottom-10.png" narrow="true" mobile_fullwidth="true" %}

Whew, you made it through the first section! I'll provide the same first several charts for the other types of requests considered–financial IDs and accounts–with no more commentary. If you'd prefer, you may <a href="#colophon">skip to the end, where I talk about how I crunched the numbers</a>.

## Financial Identifier Requests

{% include blog-post-image.html source="atr-2018h1/requested-financial-ids-top-10.png" narrow="true" mobile_fullwidth="true" %}

<center><font size="80pt">***</font></center>

{% include blog-post-image.html source="atr-2018h1/financial-id-requests-top-10.png" narrow="true" mobile_fullwidth="true" %}

<center><font size="80pt">***</font></center>

{% include blog-post-image.html source="atr-2018h1/requested-financial-ids-over-time.png" narrow="true" mobile_fullwidth="true" %}

<center><font size="80pt">***</font></center>

{% include blog-post-image.html source="atr-2018h1/requested-financial-id-amount-distribution.png" narrow="true" mobile_fullwidth="true" alt="Mean: 817.2 financial IDs; standard deviation: 2447.7 financial IDs." %}

<center><font size="80pt">***</font></center>

{% include blog-post-image.html source="atr-2018h1/percentage-honored-financial-id-requests-top-10.png" narrow="true" mobile_fullwidth="true" %}

<center><font size="80pt">***</font></center>

{% include blog-post-image.html source="atr-2018h1/percentage-honored-financial-id-requests-over-time.png" narrow="true" mobile_fullwidth="true" %}

<center><font size="80pt">***</font></center>

{% include blog-post-image.html source="atr-2018h1/honored-financial-id-request-percentage-distribution.png" narrow="true" mobile_fullwidth="true" alt="Mean: 77.2%; standard deviation: 26.5%." %}

## Account Requests

{% include blog-post-image.html source="atr-2018h1/requested-accounts-top-10.png" narrow="true" mobile_fullwidth="true" %}

<center><font size="80pt">***</font></center>

{% include blog-post-image.html source="atr-2018h1/account-requests-top-10.png" narrow="true" mobile_fullwidth="true" %}

<center><font size="80pt">***</font></center>

{% include blog-post-image.html source="atr-2018h1/requested-accounts-over-time.png" narrow="true" mobile_fullwidth="true" %}

<center><font size="80pt">***</font></center>

{% include blog-post-image.html source="atr-2018h1/requested-account-amount-distribution.png" narrow="true" mobile_fullwidth="true" alt="923.7 accounts; standard deviation: 3786.6 accounts." %}

> Need a break from the charts? How about this interesting TIL I found while writing this post: [the 68-95-99.7 rule (aka empirical rule)](https://en.wikipedia.org/wiki/68–95–99.7_rule), a mnemonic to remember the percentages of a normally distributed population within 1, 2 and 3 standard deviations from the mean, respectively.

{% include blog-post-image.html source="atr-2018h1/percentage-honored-account-requests-top-10.png" narrow="true" mobile_fullwidth="true" %}

<center><font size="80pt">***</font></center>

{% include blog-post-image.html source="atr-2018h1/percentage-honored-account-requests-over-time.png" narrow="true" mobile_fullwidth="true" %}

<center><font size="80pt">***</font></center>

{% include blog-post-image.html source="atr-2018h1/honored-account-request-percentage-distribution.png" narrow="true" mobile_fullwidth="true" alt="Mean: 64.1%; standard deviation: 34.5%." %}

# Colophon
<a name="colophone" />
To compile these numbers from the CSV, I used my [FastMath](https://github.com/tworingsoft/fastmath) and [Pippin](https://github.com/tworingsoft/pippin) Swift libraries, adding some new functions along the way (they're now at versions 2.2.1 and 12.1.0, respectively). The [code specific to working with Apple's CSVs](https://github.com/TwoRingSoft/blog-projects) lives in an Xcode test suite. (I discovered the excellent [cocoapods-playgrounds](https://github.com/asmallteapot/cocoapods-playgrounds) and used it to set up an Xcode Playground initially, but wound up moving to a test suite to get better IDE supports working on the code.)

I used Numbers.app to create the final charts from my program's output. I could not find a Swift drop-in graphing library that worked flawlessly for my needs; I evaluated [Charts](https://github.com/danielgindi/Charts), [SwiftCharts](https://github.com/i-schuetz/SwiftCharts) and [core-plot](https://github.com/core-plot/core-plot) (I also found [PNChart](https://github.com/kevinzhow/PNChart) after writing, which looks quite nice).

# Coming Up Next

As part of researching for this post, I discovered a few new ways to visualize data I'd like to try, including [box plots](https://en.wikipedia.org/wiki/Box_plot) of [5 number summaries](https://en.wikipedia.org/wiki/Five-number_summary) of various distributions, even plotted over time. I'd like to move it from an Xcode unit test suite to a command line application, linking FastMath and Pippin statically instead of the venerated `use_frameworks!` in my Podfile. It'd be nice to have a [web] app that dynamically renders all these charts, so I don't have to use Pages.app any more! And finally, I'd like to see how these data correspond to others, like countries' device sales, GDP, population, law enforcement and/or defense spending, or incarceration rate.

Perhaps now that the groundwork is laid, I'll get to some of that for the next Transparency report around June 😎
