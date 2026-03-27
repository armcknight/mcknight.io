---
title: Well watered
date: 2025-03-11
author: Andrew McKnight
layout: post
tags: diy
abstract: "Adventures in plumbing and electricity."
---
The cabin we bought a few years ago runs on a well. A pressure tank inside supplies the house, and when the pressure dips low enough, a pressure switch turns on power to the well to pump more water in.

Right at the beginning of winter, we noticed this pump running more frequently, meaning pressure was being slowly lost somewhere. We ruled out a waterlogged tank, and replaced the interior check valve, but the issue persisted. We concluded there is a leak somewhere in the well.

It took a while to get a hold of a well drilling and repair company, but after a couple weeks I got a callback from the company that originally drilled ours in 1970 (albeit, the previous generation of the family that runs it). I also spoke with one other whose boom truck was out of commission, and they didn't have a timeline of when it'd be fixed (but they _did_ have a backlog of people needing service).

I had an appointment in a few days, but problem: the wellhead is on the other side of our house from our driveway, surrounded by a 3 foot snowpack. In order to get a boom truck to it, I'd need a lane 8 feet wide, which I cleared with a snowblower, about 100 feet to the driveway, plus area on the hillside to place pipes as they work.

When they came to have a look, though, they said that since the wellhead itself is on such sloped ground, there's no way they could safely park the boom truck to work on it, or be able to drive away afterwards. The two options are, truck in infill to level the ground enough for the truck, or wait till spring to try a new pump pulling machine they bought. They haven't used it yet so wanted to get experience with it, and had a job coming up to do so. But, because it depends on friction, they don't want to use it until it's staying safely above freezing.

So, it won't be fixed today, and realistically not until April or May.

So, we need a backup solution.

Which I just finished last night, almost 3 months after that meeting.

Another family at our daycare had also had a well fail this winter, and were working on a backup holding tank solution. Sounds good.

So I got a 200 gallon polyethylene tank ($450 from a [Greer Tank](https://greertank.com), a fabricator in Fairbanks), a 1/2 horsepower jet pump from [Ferguson's Plumbing Supply](https://www.ferguson.com/store/ak/fairbanks/plumbingpvf-3022) (after initially buying a 1/12 HP pump and realizing it wouldn't be strong enough) and had a couple sections of high pressure hose sections custom made with swivel fittings on each end from [Alaska Hose and Fitting Supply](https://akhfs.com). I hooked these together with a 2-way shutoff valve that connects them to the spigot in between the interior check valve and pressure tank. This way, with one valve configuration, I can run the well pump to fill the holding tank, and with another, I can have the jet pump take water from the tank and pump it to the pressure tank. I eventually found a [video](https://www.youtube.com/watch?v=5-Cc9tvfUrE) that explains a similar setup pretty well. The pump I eventually settled on also had a diagram of the setup as one of its popular uses.

{% include blog-post-image.html source="well-backup-system.JPG" %}

The pump doesn't, however, just come with a plug you can stick in a wall outlet. The pressure switch that comes attached to it can be wired for any number of applications, so you have to do this last bit yourself. I got some 16-3 wire and a male 3-prong connector and made my own plug for it. I misunderstood the wiring diagram that comes in the switch's housing and short circuited on my first attempt, ruining an extension cord, but mercifully not the $900 pump. After finding a [video](https://www.youtube.com/watch?v=mVR9Wns0ST8) online, I was able to fix the issue and it worked on the second try (after asking another friend for a second opinion-and they'd also watched my first attempt on FaceTime, as I was watching my daughter alone that night and wanted to make sure someone knew what was happening in case I shocked myself).

The pressure switch that comes connected to the jet pump is documented to come preset at 30-50: turn the pump on if PSI is at or below 30 PSI, and turn it off when at or above 50 PSI. However, the switch for the well is set to 40-60, calibrated to the pressure tank on the low end and normal home plumbing pressure at the high end. It took a while to find information on how to adjust these, but I eventually found a [video](https://www.youtube.com/watch?v=FZOJsWILWiA) explaining that tightening the cut in nut 3 full turns would raise the cutin pressure by 10 PSI, which is what I'd need to get back to the 40-60 system. I wound up needing to do an extra quarter turn to get it right at 40. Then, it would cut out only at 50 or so, I had to tighten the range nut 16 times as far as the wrench could turn, maybe only 20 degrees–it's wedged pretty tightly next to the pump motor body–so just under one full turn of the nut. Thinking back, I could've probably just set the nuts at the same levels as the well's pressure switch, as they're essentially the same exact model, just made from different manufacturers: one is a Square D, the other Telemecanique–they even have the same wiring diagram on the inside of the cover. But, I wound up still needing to tighten the nuts a little further on the pump's, which I chalk up to it being further away from the pressure gauge in the well's system.

The pressure switch that controls the well has an on/off/auto switch built in that I could hold in the "on" position (it won't stay there on its own, falling either to auto or off, so I rigged a pair of vice grips to hold it between the two) but this stopped working at some point, so I had to join the two discontinuous wires being switched by it and just run the well from the breaker panel. The circuits for the well and the outlet the jet pump is plugged into are different so that makes it easier to operate each mode separately.

One thing I missed was a check valve in between the pump and holding tank. It was even in the diagram for the setup I wanted in the pump's manual, but I missed that detail. So, when I initially tried running it, it would rapidly cycle off and on, and once it stopped, the water ran back into the holding tank, reducing the pressure to its cutoff level and turning it back on, sometimes for several seconds, sometimes only for an instant. Installing the check valve fixed that issue.

Once I solved the switch chatter, the pump ran smoothly, pressurizing the tank to the same level as before, and then shutting off. Perfect, except for one thing. There was no water coming out of the faucents. When I was troubleshooting way back when this all started, I had accidentally let the whole house drain down the well, forgetting to close the valve after the pressure tank before draining the system to check its inner air bladder pressure. So, I had an air lock in the system. I once more drained the house (back into the holding tank, this time) and then closed that valve to the house, repressurized the tank, opened every faucet in the house, and then cracked the valve open just 5%, enough to let water trickle in, gently pushing the air out of the pipes, instead of violently mixing with it and trapping it again. One by one, each faucet had a weak, but consistent stream appear, and I shut them off one by one until voilà, a full-pressure, continuous stream was able to be produced out of each one.

Hopefully this will get us to a well repair later this spring. The tank will be repurposed into a rain collector (joining a slightly larger 300 gallon version of the same general model already being used for this on the other side of the property).

Original setup:
<pre>
                                         +-----------+
                                         |           |
                                         |           |
                                         |           |
                      Pressure Pressure  | Pressure  |
                       switch   gauge    |   tank    |
                        +----+  +--+     |           |
                        |    |  |  |     |           |
                        +----+  +--+     |           |
      +------------+      |       |      +-----------+
      |   Check    |      |       |            |         +-------+
|-----|   valve    |------|-------|------------|---------| Valve |------ to house
|     +------------+                                     +-------+
|
|
--------------------------------------|--------------------------------- from well
                                      |
                                      |
                                    +--+
                                    |  |
                                    +--+
                                   Spigot
</pre>
Setup with backup system:
<pre>

                             +---------------------------------------------------------------|
                             |                                                               |
                             |                                                               |
                             |                                                               |
                             |               +-----------+                                   |
                             |               |           |                                   |
                             |               |           |                                   |
                             |               |           |                                   |
                          Pressure Pressure  | Pressure  |                                   |
                           switch   gauge    |   tank    |                                   |
                            +----+  +--+     |           |                                   |
                            |    |  |  |     |           |                                   |
                            +----+  +--+     |           |                                   |
          +------------+      |       |      +-----------+                                   |
          |   Check    |      |       |            |         +-------+                       |
    |---->|   valve    |--------------|--------------------->| Valve |-----> to house        |
    |     +------------+                                     +-------+                       |
    |                                                                                        |
    |                                                                                        |
    --------------------------------------|------------------------<-------- from well       |
                                          |                                                  |
                                          |                                                  |
             +---------------           +--+                                                 |
             |              |           |  |                                                 |
             |              |           +--+                                                 |
+--------------------+      |          Spigot                                                |
|                    |      |             |                                                  |         240V       well
|                    |      |             |                                                  +-------- relay ---- motor
|                    |      |         |-------|
|                    |      |         |       |
|                    |      |         |2-way  |
|                    |      |         |shutoff|
|                    |      |         |valve  |                                                         115V
|                    |      +----------       -----------------------+                  +------------- outlet
|                    |                                               |                  |
|                    |                                               |                  |
|      Holding       |                                               |                  |
|       tank         |                                               |                  |
|                    |                                               |                  |
|                    |                                               |                  |
|                    |                                               |                  |
|                    |                                               |                  |
|                    |                                               |              +--------+
|                    |                                               |              |Pressure|
|                    |                                               |              | switch |
|                    |                                          +----|--------------+--------+
|                    |                                          |                            |
|                    +-------+                +---------+       |                            |
|                    | Valve |--------------->|  Check  |------->         Jet pump           |
+--------------------+-------+                |  valve  |       |                            |
                                              +---------+       +----------------------------+
</pre>
