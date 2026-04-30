---
key: 'ecmp'
publish: true
author: 'Jack Henry'
title: "Next-Hop Selection with the Hash-Threshold Algorithm"
description: "A method to select a next-hop in a multi-path network"
pubDate: 2026-01-08
tags:
  - ecmp
  - multipath
  - algorithm
---

## Introduction

The topic of this article is Equal-Cost Multi-Path (*ECMP*). Chosen primarily due to its apparent simplicity. A forwarding device, like a router, load-balances across multiple next-hops equally. That's the essence of ECMP. In the real world, ECMP routing is implemented differently across vendor devices. There are no strict standards for implementing it since it's just a routing strategy. Therefore, this article investigates what a vendor implementation of ECMP might look like. At the heart of the implementation is the next-hop selection algorithm. There are multiple approaches to this algorithm. This article showcases the *Hash-Threshold* approach with a demo implementation. 

## The RFCs

IETF's [RFC 2991](https://datatracker.ietf.org/doc/html/rfc2991) and [RFC 2992](https://datatracker.ietf.org/doc/html/rfc2992) center around ECMP and next-hop selection algorithms. Multiple algorithms are discussed and analyzed. Most notably, they discuss the concept of *disruption* in a multi-path network. Disruption can occur to network flows which are sensitive to changes in next-hops. For example, a TCP flow will fall apart if a forwarding device suddenly changes the hop it's being routed through.

The approaches in RFCs 2991 & 2992 were designed around the issue of disruption. Special attention is placed on the *Hash-Threshold* algorithm. Alas, this article will also place special attention on it. 

## Hash-Threshold

When forwarding a packet, clock cycles are precious. The goal is to get the packet on its way as quickly as possible. When a device has multiple possible next-hops, it needs a quick method for selecting one. Naively, the device could choose a round-robin approach. Where the least recently used next-hop is chosen at each decision point. However, TCP flows would suffer greatly from this carousel of next-hops. Instead, packets that are a part of the same flow should deterministically be routed through the same next-hop. The *Hash-Threshold* approach solves the deficiencies of the round-robin approach. The following will outline how it works:

When a device receives a packet to be forwarded, it will generate a "flow identity" for the packet. This "flow identity" is a checksum of chosen fields from the packet's header. Bytes from chosen fields are concatenated and fed through a hashing algorithm like CRC16. Choosing fields like source and destination address ensure that packets within the same flow result in the same flow identity.

After being computed for the packet, the flow identity will be used to select the next-hop. This is done by partitioning the range of the hash function. For CRC16, this means evenly partitioning `[0,65535]` and assigning each partition to a next hop. Since the flow identity is also a `u16`, the value must fall within one of the partitions. The next-hop is selected based on the partition that its flow identity falls within. 

## A Simple Demo

The process of the *Hash-Threshold* might be simpler to visualize with a toy implementation. The following rust program illustrates the steps involved in selecting a next-hop with the algorithm:

```rust
use std::net::Ipv4Addr;

const NEXT_HOPS: [Ipv4Addr; 2] = [Ipv4Addr::new(192, 168, 1, 1), Ipv4Addr::new(192, 168, 2, 1)];

fn main() {
    let src = Ipv4Addr::new(10, 0, 0, 201);
    let dst = Ipv4Addr::new(1, 1, 1, 1);
    let combined = ((src.to_bits() as u64) << 32) | (dst.to_bits() as u64);
    let sum = checksum(&combined.to_be_bytes());
    let next_hop = get_nexthop(&sum);
    println!("{:?}", next_hop);
}

pub fn checksum(msg: &[u8]) -> u16 {
    let mut crc: u16 = 0x0;
    for byte in msg.iter() {
        let mut x = ((crc >> 8) ^ (*byte as u16)) & 255;
        x ^= x >> 4;
        crc = (crc << 8) ^ (x << 12) ^ (x << 5) ^ x;
    }
    crc
}

pub fn get_nexthop(flow_checksum: &u16) -> Ipv4Addr {
    let next_hop_count = NEXT_HOPS.len();
    let index = (*flow_checksum as u32 * next_hop_count as u32) >> 16;
    return NEXT_HOPS[index as usize];
}
```

> [!TIP]
> This small program uses the `std::net::Ipv4Addr` struct to avoid boilerplate and keep it simple. However, this could easily be re-written to accommodate `no_std` environments.

```rust
const NEXT_HOPS: [Ipv4Addr; 2] = [Ipv4Addr::new(192, 168, 1, 1), Ipv4Addr::new(192, 168, 2, 1)];
```

These are the possible next-hops. In the real-world, this would not be a `const`. ECMP is used in conjunction with dynamic routing protocols like OSPF and IS-IS. Therefore, the number of next-hops available might not be static.

```rust
fn main() {
    let src = Ipv4Addr::new(10, 0, 0, 201);
    let dst = Ipv4Addr::new(1, 1, 1, 1);
    let combined = ((src.to_bits() as u64) << 32) | (dst.to_bits() as u64);
    let sum = checksum(&combined.to_be_bytes());
    let next_hop = get_nexthop(&sum);
    println!("{:?}", next_hop);
}
```

This is the entry point of the program. A flow identity is constructed from a source address of `10.0.0.201` and a destination address of `1.1.1.1`. These values would be extracted from a packet's header.

An IPv4 address is 32 bits. The source and destination address are concatenated to each other through a bit shift and an OR operation. The result is a 64 bit value and a reference is passed to the `checksum` function. The checksum value returned is then fed to a `get_nexthop` function.

```rust
pub fn checksum(msg: &[u8]) -> u16 {
    let mut crc: u16 = 0x0;
    for byte in msg.iter() {
        let mut x = ((crc >> 8) ^ (*byte as u16)) & 255;
        x ^= x >> 4;
        crc = (crc << 8) ^ (x << 12) ^ (x << 5) ^ x;
    }
    crc
}
```
The checksum function is an implementation of the CRC16 algorithm. I'm not a cryptography expert, so I leaned on stackoverflow for this. There's a single `for` loop in the function which iterates over the bytes which `msg` refers to. However, we know that this value is always of type `[u8; 8]`. Therefore, this loop will always iterate 8 times.

```rust
pub fn get_nexthop(flow_checksum: &u16) -> Ipv4Addr {
    let next_hop_count = NEXT_HOPS.len();
    let index = (*flow_checksum as u32 * next_hop_count as u32) >> 16;
    return NEXT_HOPS[index as usize];
}
```

This is a constant-time method for retrieving the next-hop from the CRC16 checksum computed by the `checksum` function. Bitwise operations are used to effectively run the calculation `index = floor(flow_checksum / 65536 * next_hop_count)`. This enforces the assertion: `0 <= index <= next_hop_count`. Additionally, a flow identity always maps to the same next-hop. 

Overall, the implementation is performant and minimizes clock cycles. In fact, since only statically sized packet header fields were used for generating flow identities, the entire execution of the program is done in constant time.

## Conclusion

The *Hash-Threshold* algorithm is capable of being a performant solution to the next-hop selection problem. Even better, it's simple to implement. This was demonstrated with a simple Rust program.

There are multiple approaches to next-hop selection in ECMP. It's not necessary to know every approach. However, for a network operator, it's necessary to recognize most algorithms fundamentally rely on flow identities. Furthermore, a vendor's routing stack often allows tweaking of this behavior. 
