---
title: "Backend to Basics"
date: 2018-10-24
layout: post
abstract: Catching up on some experimentation with different backend, one of which was the Vapor framework for Swift on the server.
author: Andrew McKnight
author-email: andrew@tworingsoft.com
tags: backend swift vapor
---

About a month ago I wrote about my continued [tribulations with setting up a Rails installation](/blog/2018/09/25/my-holy-grail-a-simple-Rails-install.html) locally on my dev machine. Once I figured things out, I codified it into a repository holding a simple [Hello World! on Rails](https://github.com/armcknight/rails-hello-world). Then I wondered what it was like to set up some other backend systems, so I made a collection of Hello World! examples for [django](https://github.com/armcknight/django-hello-world), [sinatra](https://github.com/armcknight/sinatra-hello-world) and [node](https://github.com/armcknight/rails-hello-world), all deployable locally or on Heroku. Of these, I think that Django actually was my favorite in terms of how the dev environment operates and how code is structured, even though I don't like Python as a programming language very much.

Also, these are all interpreted languages, and I like to work with compiled languages for applications if possible. (I usually use interpreted languages for complicated scripting that's too complicated for shell scripts.) I learned enough Rust to put together a Hello World!, and then it occurred to me that there's another compiled language I can use on the server, that I already know well, and love: Swift!

So I created a [Swift server Hello World!](https://github.com/armcknight/vapor-hello-world) using [Vapor](https://vapor.codes), which has quite an ecosystem around it today via [vapor](https://github.com/vapor) and [vapor-community](https://github.com/vapor-community) on GitHub, which have tons of helpful tools for backend needs:

- payments: [Stripe-provider](https://github.com/vapor-community/stripe-provider)
- security:
	- [moat](https://github.com/vapor-community/moat)
	- [CSRF](https://github.com/vapor-community/CSRF)
- communications:
	- Apple push notifications: [apns](https://github.com/vapor-community/apns)
	- Telesign: [Telesign-provider](https://github.com/vapor-community/telesign-provider)
	- SendGrid: [sendgrid-provider](https://github.com/vapor-community/sendgrid-provider)
- auth
	- [auth-provider](https://github.com/vapor-community/redis-provider)
	- [Imperial](https://github.com/vapor-community/Imperial)
- monitoring: [VaporMonitoring](https://github.com/vapor-community/VaporMonitoring)
- databases:
	- [postgresql-provider](https://github.com/vapor-community/postgresql-provider)
	- [mongo-provider](https://github.com/vapor-community/mongo-provider)
	- [redis-provider](https://github.com/vapor-community/redis-provider)
	- [sqlite-provider](https://github.com/vapor-community/sqlite-provider)
	- Firebase: [ferno](https://github.com/vapor-community/ferno)
- forms: [forms](https://github.com/vapor-community/forms)
- validation: [validation-provider](https://github.com/vapor-community/validation-provider)
- templating: 
	- leaf, Vapor's native templates: [leaf-provider](https://github.com/vapor-community/leaf-provider)
	- Mustache: [mustache-provider](https://github.com/vapor-community/mustache-provider)

...and lots more. I implemented another example of a Vapor server app with a PostgreSQL database connection, deployable on Heroku: [vapor-postgres](https://github.com/armcknight/vapor-postgres).
