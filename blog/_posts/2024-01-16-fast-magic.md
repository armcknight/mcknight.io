---
title: "Fast Magic"
date: 2024-1-17
layout: post
abstract: "Building a Swift CLI to manage my Magic: the Gathering card collection."
author: Andrew McKnight
tags: swift mtg
---

I recently found my old Magic cards while cleaning out my father's home and storage unit. I hadn't played-or really even thought about-the game in almost 25 years. The nostalgia hit hard and I've been back in action for the past several months. There has been a lot to learn since I last played: new card designs, new play formats, new mechanics and rules, and lots and LOTS of new cards have been printed. There are 90,661 entries in the last data dump I downloaded from Scryfall. By my estimation, that's just a few more details than I can master. Not for lack of trying, though; I've been voraciously reading up on the various wikis and subreddits out there dedicated to the cause. But I still needed something more.

# Tools

There are lots of tools out there. Some free, some paid. But as is often the case with software, it's hard to find something that does exactly what you want. So I set out to write my own tool.

My starting point was scanning each card I purchase with [TCGPlayer's iOS app](https://apps.apple.com/us/app/tcgplayer/id1247645833). This lets you export a CSV that I used to open my card list in a spreadsheet. But I quickly realized I would need more information. For one thing, the TCGPlayer export doesn't contain any of the things you see on the card besides its name, which set it's from, and its card number in that set. This makes sense because TCGPlayer is geared towards _selling_ cards, not _understanding_ them. I need to get color identity, abilities, power/toughness, CMC... and for that, I turn to [Scryfall](https://scryfall.com).

Ultimately, I want something akin to MTGGoldfish's SuperBrew deck builder that, given a particular deck you want to build, can tell you which of the cards you already own and what you're missing. And I also want something where I can search for every card with a particular ability, like flying or proliferate. And maybe also something that can optimize for a particular mana curve. And maybe something that can help identify combos, like [Commander Spellbook](https://commanderspellbook.com).

There is plenty to say (although maybe it's already all been said online already) about "netdecking", and I think it's fine and do it, but I also like building decks using what I already have on hand. That's essentially what I want a tool to help with.

# My Swift CLI

Where I'm at as of writing this is to ingest a CSV from the TCGPlayer of scanned cards, put that card in a list of either stored collection or in a deck that's in use, and also inject all the cards' gameplay details from Scryfall bulk data downloads or from their API directly, using the card number and set code from TCGPlayer to query for the same card in Scryfall.

I'm using [SwiftCSV](https://github.com/swiftcsv/SwiftCSV) to parse the CSV I get from TCGPlayer, and Swift's builtin JSONDecoder to parse the Scryfall bulk data download (it took 2.84 seconds to parse a 416.4 MB file in an optimized build!). It will fall back to hitting the API directly if there's no local bulk data file. Also, the bulk data download is just one big array of objects, so to make querying faster, it transforms it into a dictionary keyed on each card set, and then each value is another dictionary keyed on card number (this mimics the API queries which are of the form `https://api.scryfall.com/card/<set>/<cardNumber>`). Before writing to the managed CSV files, it loops through the entire set of cards and consolidates the cards that appear in multiple different rows, summing the quanties; because hey, you're always gonna get more of the same commons when drafting or cracking packs!

And so now I have a spreadsheet with 65 columns. We're ready to crunch!

{% include
	blog-post-image.html
	source="mtg-spreadsheet.png"
	alt="65 columns of MtG card data to crunch!" %}

You can follow along with my progress at [https://github.com/armcknight/mtg](https://github.com/armcknight/mtg).

# Learnings

The set of all MtG cards is pretty complex: beyond the myriad abilities and keywords, there are reprints (with errata!), multiple variants of cards like multiple types of foiling, alternate art layouts like extended/borderless/showcase, promotional versions of cards. Here are some of the interesting things I learned while trying to translate from TCGPlayer's data set to Scryfall's.

**Double quotes inside double-quoted CSV fields (because they contain commas)**

Before even getting data from Scryfall at all, I had to parse the CSV and be able to output it in my own format (I added an extra field for the time and date at which the TCGPlayer was retrieved; price information can change drastically over time). Some card names have commas in them, and whenever you have commas in your CSV data, you have to surround the field with quotes. But what happens if you use double quotes to surround field data, and then the field data itself also contains double quotes? This happened a few times, such as for a [card from a world championship deck that had the player's nickname in double quotes as part of the card name](https://www.tcgplayer.com/product/160810/magic-world-championship-decks-memory-lapse-version-2-1996-shawn-hammer-regnier-hml-sb?xid=pic7182816-f4f0-4945-990e-7baaf82e0521&Language=English&page=1) (which was actually mis-scanned-I didn't have this particular version of this card, but a normal printing). Now, the first inner double quote would close the first encapsulating quote, and all the remaining row data would be offset. I learned that RFC 4180 specifies that inner double quotes are to be escaped by simply doubling the double quotes, so `"` becomes `""`.

**non-ASCII characters in URLs, and sometimes numbers are not numbers**

One more RFC-related learning was related to encoding non-ASCII characters. This is also a learning about Apple's `NSURL` and `NSURLComponents` API: `NSURL`'s docs state:

> For apps linked on or after iOS 17 and aligned OS versions, URL parsing has updated from the obsolete RFC 1738/1808 parsing to the same RFC 3986 parsing as URLComponents. This unifies the parsing behaviors of the URL and URLComponents APIs. Now, URL automatically percent- and IDNA-encodes invalid characters to help create a valid URL.

I found out that even though each card has a "number" that WotC, TCGPlayer and Scryfall all use to identify cards, this field can contain more than just numbers (it's a string in Scryfall's [schema](https://github.com/scryfall/api-types/blob/60147b5db0627d8b65024dcf96a5af168075af56/src/objects/Card/CardFields.ts#L233-L234): it can also have characters like ★, Φ, or †, or letters, or leading zeroes that you won't be able to correctly retrieve from an integer primitive). Simply switching from calling `URL(string: "https://api.scryfall.com/card/\(setCode)/\(cardNumber)")` to using `URLComponents(string:)` and then accessing its `.url` property, I got the encoding for free.

**All models are wrong, and in different and interesting ways**

_All models are wrong, some are useful. -George Box_

Again, these are huge, complex data sets. And they're, I presume, completely hand-curated. There are going to be some errors. I hit numerous instances of inaccuracies in both TCGPlayer and Scryfall, where e.g. a card's rarity was stated incorrectly in one or the other. Card numbers may differ between what you see on the card itself and what it's listed as in the database: for instance, all the cards in the 30th Anniversary Misc Promos (P30M) set are numbered 1 (actually, 001, or 0001), but Scryfall stores them as ["1F★"](https://scryfall.com/card/p30m/1F★/arcane-signet), ["2"](https://scryfall.com/card/p30m/2/lotus-petal), ["1F"](https://scryfall.com/card/p30m/1F/arcane-signet), ["1P"](https://scryfall.com/card/p30m/1P/arcane-signet) and ["1★"](https://scryfall.com/card/p30m/1★/richard-garfield-phd).

**Set membership and unique IDs**

Some sets, like "The List", are called by one set code identifier in TCGPlayer ("LIST") and another in Scryfall ("plist"). Some sets are actually anthologies containing subsets, like [Duel Deck Anthologies](https://mtg.fandom.com/wiki/Duel_Decks_Anthology) (set code DD3), which contain the subsets Elves vs. Goblins (EVG), Jace vs. Chandra (DD2), Divine vs. Demonic (DDC) and Garruk vs. Liliana (DDD); one card, ["Stonewood Invoker"](https://scryfall.com/card/evg/11/stonewood-invoker), was listed as card number 11 from Elves vs. Goblins, which TCGPlayer calls DD3 (the superset code for Duel Decks Anthologies), but in Scryfall it is under either EVG (which it calls DDA: Elves vs. Goblins) or DD1. Why the same listing under two different names for the same set? Where did DDA and DD1 come from? I haven't found them elsewhere.

"The List" is a set of reprints of cards from other sets; sometimes, two cards from different sets will have the same card number in their respective set, so need to be disambiguated in the LIST/plist set in the databases. For example, ["Direct Current"](https://www.cardkingdom.com/mtg/mystery-booster-the-list/direct-current) from "The List" is number 96 in Guilds of Ravnica (GRN), but Scryfall has ["Gatekeeper of Malakir"](https://scryfall.com/card/plist/96/gatekeeper-of-malakir) as card number 96 in The List set–even though it's actually card number 89 in the set it's from (Zendikar)! Also note that Scryfall doesn't have a listing for Direct Current in The List at all.

**Naming things, amirite?**

Even something like the "rarity" of a card is described differently in TCGPlayer and Scryfall. Only TCGPlayer has rarity levels "special" and "land", and only Scryfall has a rarity level of "bonus".

# Solutions

I wrote several hacks to work around issues with [rarity disagreement](https://github.com/armcknight/mtg/blob/61f2309d43ac0424b8093e380aaf3cc20c49a94a/mtg/Card.swift#L595-L633), [set code disagreement](https://github.com/armcknight/mtg/blob/61f2309d43ac0424b8093e380aaf3cc20c49a94a/mtg/Card.swift#L462-L503) and [card number disagreement](https://github.com/armcknight/mtg/blob/61f2309d43ac0424b8093e380aaf3cc20c49a94a/mtg/Card.swift#L505-L532).

On a final note about the hand-curation of these sets, the API schema itself as published at [https://github.com/scryfall/api-types](https://github.com/scryfall/api-types) was missing a couple values in certain cases. I opened [several PRs](https://github.com/scryfall/api-types/pulls?q=is%3Apr+sort%3Aupdated-desc+author%3Aarmcknight+), some of which were merged, others were closed because the query responses I was seeing were actually incorrect data. I also submitted several support requests to fix or add missing card data on both TCGPlayer and Scryfall.

# Shout-outs and links

Shout out to all the people that keep TCGPlayer and Scryfall ticking! As well as the other tools and communities I've found in the ecosystem. Here are the links I've saved up so far:

## Subreddits

- [https://reddit.com/r/CompetitiveEDH](https://reddit.com/r/CompetitiveEDH)
- [https://reddit.com/r/EDH](https://reddit.com/r/EDH)
- [https://reddit.com/r/magicdeckbuilding](https://reddit.com/r/magicdeckbuilding)
- [https://reddit.com/r/magictcg](https://reddit.com/r/magictcg)
- [https://reddit.com/r/mtg](https://reddit.com/r/mtg)
- [https://reddit.com/r/mtgfinance](https://reddit.com/r/mtgfinance)
- [https://reddit.com/r/mtgmemes](https://reddit.com/r/mtgmemes)
- [https://reddit.com/r/pauper](https://reddit.com/r/pauper)
- [https://reddit.com/r/sealedmtgdeals](https://reddit.com/r/sealedmtgdeals)
- [https://reddit.com/r/spikes](https://reddit.com/r/spikes)

and of course, Reddit wouldn't be Reddit without

- [https://reddit.com/r/mtgcirclejerk]()

## Card Info etc

- [https://scryfall.com](https://scryfall.com)
- [https://tcgplayer.com](https://tcgplayer.com)
- [https://mtg.fandom.com/wiki/Main_Page](https://mtg.fandom.com/wiki/Main_Page)

## Deck Building

- [https://archidekt.com](https://archidekt.com)
- [https://moxfield.com](https://moxfield.com)
- [https://tappedout.net](https://tappedout.net)
- [https://deckbox.org](https://deckbox.org)
- [https://edhrec.com](https://edhrec.com)
- [https://mtggoldfish.com](https://mtggoldfish.com)
- [https://mtgdecks.net](https://mtgdecks.net)
- [https://deckstats.net](https://deckstats.net)

## Combo Search

- [https://commanderspellbook.com](https://commanderspellbook.com)
- [https://mtg.cardsrealm.com/en-=us/combo-infinite](https://mtg.cardsrealm.com/en-=us/combo-infinite)
- [https://combo-finder.com](https://combo-finder.com)
- [https://edh-combos.com/combo](https://edh-combos.com/combo)
- [https://ineedacombo.com/magic-the-gathering/post](https://ineedacombo.com/magic-the-gathering/post)
