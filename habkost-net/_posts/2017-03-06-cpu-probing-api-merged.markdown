---
layout: post
title: 'The long story of the query-cpu-model-expansion QEMU interface'
slug: qemu-cpu-model-probing-story
categories: virt
date: 2017-03-06 17:00:00
comments: true
---
So, finally the [`query-cpu-model-expansion` x86 implementation was merged
into qemu.git](https://github.com/qemu/qemu/commit/666095c852d32df65b5982fcc8c85332979b7fc1),
just before 2.9 soft freeze. Jiri Denemark already implemented
the x86 libvirt code to use it. I just can't believe this was
finally done after so many years.

<!--more-->

It was a weird journey. It started almost 6 years ago with this
message to qemu-devel:

> Date: Fri, 10 Jun 2011 18:36:37 -0300<br>
> Subject: <a href="https://www.mail-archive.com/kvm@vger.kernel.org/msg55640.html">semantics of "-cpu host" and "check"/"enforce"</a>

...it continued on an interesting thread:

> Date: Tue, 6 Mar 2012 15:27:53 -0300<br>
> Subject: <a href="http://www.mail-archive.com/qemu-devel@nongnu.org/msg100533.html">Qemu, libvirt, and CPU models</a>

...on another very long one:

> Date: Fri, 9 Mar 2012 17:56:52 -0300<br>
> Subject: <a href="http://www.mail-archive.com/qemu-devel@nongnu.org/msg101215.html">Re: [Qemu-devel] [libvirt] Modern CPU models cannot be used with libvirt</a>

...and this one:

> Date: Thu, 21 Feb 2013 11:58:18 -0300<br>
> Subject: <a href="http://www.mail-archive.com/qemu-devel@nongnu.org/msg156534.html">libvirt<->QEMU interfaces for CPU models</a>

I don't even remember how many different interfaces were proposed
to provide what libvirt needed.

We had a few moments where we hopped back and forth between "just
let libvirt manage everything" to "let's keep this managed by
QEMU".

We took a while to get the QEMU community to decide how machine-type
compatibility was supposed to be handled, and what to do
with the weird CPU model config file we had.

The conversion of CPUs to QOM was fun. I think it started in 2012
and was finished only in 2015. We thought QOM properties would
solve all our problems, but then we found out that machine-types
and global properties make the problem more complex. The existing
interfaces would require making libvirt re-run QEMU multiple
times to gather all the information it needed. While doing the
QOM work, we spent some time fixing or working around issues with
global properties, qdev "static" properties and QOM "dynamic"
properties.

In 2014, my focus was moved to machine-types, in the hope that we
could finally expose machine-type-specific information to libvirt
without re-running QEMU. Useful code refactoring was done for
that, but in the end we never added the really relevant
information to the `query-machines` QMP command.

In the meantime, we had the
<a href="https://bugzilla.redhat.com/show_bug.cgi?id=1199446">fun TSX issues</a>,
and QEMU developers finally agreed to keep a few constraints on CPU
model changes, that would make the problem a bit simpler.

In 2015 IBM people started sending patches related to CPU models
in s390x. We finally had a multi-architecture effort to make CPU
model probing work. The work started by extending
`query-cpu-definitions`, but it was not enough. In June 2016 they
proposed a `query-cpu-model-expansion` API. It was finally merged
in September 2016.

I sent v1 of `query-cpu-model-expansion` for x86 in December 2016.
After a few rounds of reviews, there was a proposal to use
"-cpu max" to represent the "all features supported by this QEMU
binary on this host". v3 of the series was
[merged last week](https://github.com/qemu/qemu/commit/666095c852d32df65b5982fcc8c85332979b7fc1).

I still can't believe it finally happened.

Special thanks to:
* Igor Mammedov, for all the x86 QOM/properties work and all the
  valuable feedback.
* David Hildenbrand and Michael Mueller, for moving forward the
  API design and the s390x implementation.
* Jiri Denemark, for the libvirt work, valuable discussions and
  design feedback, and for the patience during the process.
* Daniel P. Berrangé, for the valuable feedback and for helping
  making QEMU developers listen to libvirt developers.
* Andreas Färber, for the work as maintainer of QOM and the CPU
  core, for leading the QOM conversion effort, and all the
  valuable feedback.
* Markus Armbruster and Paolo Bonzini, for valuable feedback on
  design discussions.
* Many others that were involved in the effort.
