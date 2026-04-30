---
key: 'big-snmp'
publish: true
author: 'Jack Henry'
title: 'DOSing yourself with SNMP'
description: "A router was wantonly updated. Afterwhich, it began working up a sweat."
pubDate: 2025-09-23
tags:
  - networking
  - mikrotik
  - SNMP
---

Around the release of RouterOS `7.18`, a fun new issue manifested itself into my life. Through unraveling the cause, an interesting interaction of SNMP in the RouterOS platform was found. Now I present a quick write-up of what was discovered and perhaps some advice:

## Discovery

Clients began reporting reliability issues shortly after we updated a couple of [CCR2004s](https://mikrotik.com/product/ccr2004_1g_12s_2xs) from `7.16.2` to `7.18.1`. Afflicted devices would lose adjacency on OSPF PTP links. Although, adjacency would quickly recover and remain stable for some hours.

The cause of the momentary, yet devastating, OSPF failures wasn't immediately evident. It happened at mostly random times and irregular intervals. However, I was luckily given some small crumbs:

```
 2025-08-11 02:10:31 snmp,warning SNMP did not get OID data within expected time, ignoring OID
```
The occurrence of the above log message typically happened in the very early hours of the morning. Typically around 2AM. It didn't seem too ominous a message. However, it felt worth tracking down. Especially since I'm aware of the network monitoring system (NMS) which regularly queries routers on the network. This seemed a likely culprit as the source of the log message.

## Anything in the Docs? 

The afflicted routers were Mikrotik. Mikrotik publishes documentation for their RouterOS and devices. Perhaps the documentation contains more valuable *context* to the message? 

There's actually an entire aside about this warning message on the Mikrotik wiki. Pretty lucky, right? Let's take a quick gander:

> SNMP tool collects data from different services running on the system. If, for some reason, communication between SNMP and some service is taking longer time than expected (30 seconds per service, 5 minutes for routing service), you will see a warning in the log stating "timeout while waiting for program" or "SNMP did not get OID data within expected time, ignoring OID". After that, this service will deny SNMP requests for a while before even trying to get requested data again.
>
> This error has nothing to do with SNMP service itself. In most cases, such an error is printed when some slow or busy service is monitored through SNMP, and quite often, it is a service that should not be monitored through SNMP, and proper solution in such cases is to skip such OIDs on your monitoring tool. [Link to the article](https://help.mikrotik.com/docs/spaces/ROS/pages/8978519/SNMP)

According to this, some potentially unwanted OID(s) are hitting the router's SNMP subsystem. Unfortunately, not much advice is given on homing in on the OID(s) and "busy" subsystems.

## Continue Finding Info

With the default logging profile in RouterOS, the SNMP related logs aren't very verbose or helpful. Therefore, it's necessary to run a command such as this:

```
/system/logging add action=remote topics=debug,snmp
```

I ran this command on an afflicted router. It instantly began forwarding more detailed logs to a handy syslog server. After letting it collect messages for a while, I scoured through the logs and picked out several instances like this:

```
SNMP,DEBUG error: no such name
SNMP,DEBUG get 1.3.6.1.4.1.14988.1.1.1.1.1.4.12 notice
```

The logs contain all the various OIDs which are being queried by the NMS. In total, there appears to be about seven total OIDs which result in the message `error: no such name` when queried. From my surface-level glance of the Mikrotik MIB, it appears that these OIDs were once used to query information related to wireless clients? I'm not totally certain though and don't have the willpower or self-hatred to sift through MIB revisions. Regardless, the layout of OIDs probably changed in a new RouterOS release.

## A Resolution

It's now been a week since implementing a resolution. Ultimately, I was able to make the right tweaks to the NMS. This consisted mostly by updating the `MIKROTIK-MIB` file it references.

If you run into this problem, my advice is to first follow my steps of isolating the problematic OIDs. From there, figure out which host is making those SNMP queries. Finally, do what's best for your environment to stop that host from making those queries. Typically, it's going to be best to try to minimize the overall amount of SNMP queries which hit the device.

## The Baggage

Overall, I've learned quite a few things from this experience. **Foremost, SNMP can be dangerous.**

During the ordeal, the beloved NMS was essentially DOSing an important piece of network infrastructure. Weaponizing SNMP queries to wound the normal operations of a router. Granted, the root of the issue isn't really inherent to SNMP. In fact, the router vendor is more to blame.

This all seems to have been catalyzed by a Mikrotik update to the MIB layout. After making this change, the NMS began querying non-existent OIDs. For some godforsaken reason, querying non-existent OIDs is kryptonite for Mikrotik routers running newer firmware. 

While this issue was still afflicting production routers, OSPF adjacency between speakers would regularly drop a couple times a day. I suspect BFD and/or OSPF hello packets were dropped when the RouterOS subsystems got confused by unfamiliar OIDs. Alarmingly, there were no signals or clues from CPU or memory readings. One of the CCR2004s hits around 30% CPU usage during peak hours.

I would imagine this is not intended behavior for RouterOS. Even if you're flooding your routers with consistent invalid SNMP queries, it shouldn't starve other processes. On the totem pole of router sub-processes, SNMP should be sitting on the ground. In other words, this is probably a bug or some sort of unintended scheduling regression.
