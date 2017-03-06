---
layout: post
title:  An incomplete list of QEMU APIs
date:   2016-11-29 00:51:00 -0200
categories: virt
slug: incomplete-list-of-qemu-apis
comments: true
---

Having seen many people (including myself) feeling confused about
the purpose of some QEMU's internal APIs when
reviewing and contributing code to QEMU, I am trying to document
things I learned about them.

<!--more-->

I want to make more detailed blog posts about some of them,
stating their goals (as I perceive them), where they are used,
and what we can expect to see happening to them in the future.
When I do that, I will update this post to include pointers to
the more detailed content.


## QemuOpts

[Introduced in 2009](https://github.com/qemu/qemu/commit/e27c88fe9eb26648e4fb282cb3761c41f06ff18a).
Compared to the newer abstractions below, it is quite simple. As
described in the original commit: it _"stores device parameters
in a better way than unparsed strings"_. It is still used by
configuration and command-line parsing code.

Making QemuOpts work with the more modern abstractions (esp. QOM
and QAPI) may be painful. Sometimes you can pretend it is not
there, but you can't run away from it if you are dealing with
QEMU configuration or command-line parameters.

**See also:** the [Introduction to QemuOpts]({{ site.baseurl }}{% post_url 2016-12-22-qemuopts %}) blog post.


## qdev

qdev [was added to QEMU in 2009](https://github.com/qemu/qemu/commit/aae9460e244c7abe70b72ff374b3aa102bb09691).
qdev manages the QEMU _device tree_, based on a hierarchy of
_buses_ and _devices_. You can see the device tree managed by
qdev using the `info qtree` monitor command in QEMU.

qdev allows device code to register implementations of _device
types_. Machine code, on the other hand, would instantiate those
devices and configure them by setting _properties_, and not
accessing internal device data structures directly. Some devices
can be plugged from the QEMU monitor or command-line, and their
properties can be configured as arguments to the `-device` option or
`device_add` command.

From the original code:

> The theory here is that it should be possible to create a machine without
> knowledge of specific devices.  Historically board init routines have
> passed a bunch of arguments to each device, requiring the board know
> exactly which device it is dealing with.  This file provides an abstract
> API for device configuration and initialization.  Devices will generally
> inherit from a particular bus (e.g. PCI or I2C) rather than
> this API directly.

Some may argue that qdev doesn't _exist_ anymore, and was
_replaced_ by QOM. Others (including myself) describe it as being
_built on top_ of QOM. Either way you describe it, the same
features provided by the original qdev code are provided by the
QOM-based code living in `hw/core`.

See also:
* KVM Forum 2010 talk by Markus Armbruster: _"QEMU's new device model qdev"_ ([slides](http://www.linux-kvm.org/images/f/fe/2010-forum-armbru-qdev.pdf))
* KVM Forum 2011 talk by Markus Armbruster: _"QEMU's device model qdev: Where do we go from here?"_ ([slides](http://www.linux-kvm.org/images/b/bc/2011-forum-armbru-qdev.pdf). [video](https://youtu.be/Cpt5Zqs_Iq0))
* KVM Forum 2013 talk by Andreas Färber: _"Modern QEMU Devices"_ ([slides](http://www.linux-kvm.org/images/0/0b/Kvm-forum-2013-Modern-QEMU-devices.pdf), [video](https://youtu.be/9LXvZOrHwjw))


## QOM

QOM is short for _QEMU Object Model_ and was [introduced in 2011](https://github.com/qemu/qemu/commit/2f28d2ff9dce3c404b36e90e64541a4d48daf0ca).
It is heavily documented on [its header file](https://github.com/qemu/qemu/blob/master/include/qom/object.h).
It started as a generalization of qdev. Today the device tree and
backend objects are managed through the QOM object tree.

From its documentation:

> The QEMU Object Model provides a framework for registering user creatable
> types and instantiating objects from those types.  QOM provides the following
> features:
>
>  - System for dynamically registering types
>  - Support for single-inheritance of types
>  - Multiple inheritance of stateless interfaces

QOM also has a property system for introspection and
object/device configuration. qdev's property system is built on
top of QOM's property system.

Some QOM types and their properties are meant to be used
internally only (e.g. some devices that are not pluggable and
only created by machine code; accelerator objects). Some types can
be instantiated and configured directly from the QEMU monitor or
command-line (using, e.g., `-device`, `device_add`, `-object`,
`object-add`).

See also:
* KVM Forum 2014 talk by Paolo Bonzini: _"QOM exegesis and apocalypse"_ ([slides](http://www.linux-kvm.org/images/9/90/Kvmforum14-qom.pdf), [video](https://youtu.be/fnLJn7PKhyo)).


## VMState

VMState was [introduced in 2009](https://github.com/qemu/qemu/commit/9ed7d6ae0fe7abb444c65caaadb5ef307df82c60).
It was added to change the device state saving/loading (for
savevm and migration) from error-prone ad-hoc coding to a table-based approach.

From the original commit:

> This patch introduces VMState infrastructure, to convert the save/load
> functions of devices to a table approach.  This new approach has the
> following advantages:
> - it is type-safe
> - you can't have load/save functions out of sync
> - will allows us to have new interesting commands, like dump <device>, that shows all its internal state.
> - Just now, the only added type is arrays, but we can add structures.
> - Uses old load_state() function for loading old state.

See also:
* KVM Forum 2010 talk by Juan Quintela: _"Migration: How to hop from machine to machine without losing state"_ ([slides](http://www.linux-kvm.org/images/c/c4/2010-forum-migration.pdf))
* KVM Forum 2011 talk by Juan Quintela: _"Migration: one year later"_ ([slides](http://www.linux-kvm.org/images/1/1e/2011-forum-migration.pp.pdf), [video](https://youtu.be/Mhac35QQWSw))
* KVM Forum 2012 talk by Michael Roth: _"QIDL: An Embedded Language to Serialize Guest Data Structures for Live Migration"_ ([slides](http://www.linux-kvm.org/images/b/b5/2012-forum-qidl-talk.pdf))


## QMP

QMP is the _QEMU Machine Protocol_. [Introduced in 2009](https://github.com/qemu/qemu/commit/9b57c02e3e14163b576ada77ddd1d7b346a6e421). From [its documentation](https://github.com/qemu/qemu/blob/master/docs/qmp-intro.txt):

> The QEMU Machine Protocol (QMP) allows applications to operate a
> QEMU instance.
> 
> QMP is [JSON](http://www.json.org) based and features the following:
> 
> - Lightweight, text-based, easy to parse data format
> - Asynchronous messages support (i.e. events)
> - Capabilities Negotiation
> 
> For detailed information on QMP's usage, please, refer to the following files:
> 
> * qmp-spec.txt      QEMU Machine Protocol current specification
> * qmp-commands.txt  QMP supported commands (auto-generated at build-time)
> * qmp-events.txt    List of available asynchronous events

See also: KVM Forum 2010 talk by Luiz Capitulino, [A Quick Tour of the QEMU Monitor Protocol](http://www.linux-kvm.org/images/1/17/2010-forum-qmp-status-talk.pp.pdf).


## QObject

QObject was [introduced in 2009](https://github.com/qemu/qemu/commit/5a1a2356490399c9b7eb850f9065af554b18cfd1).
It was added during the work to add QMP. It provides a generic
`QObject` data type, and available subtypes include integers,
strings, lists, and dictionaries. It includes reference counting.
It was also called _QEMU Object Model_ when the code was
introduced, but do not confuse it with _QOM_.

It started a as simple implementation, but was expanded later to support
all the data types defined in the QAPI _schema_ (see below).


## QAPI

QAPI was introduced in 2011. The original
documentation (which can be outdated) can be seen at
[http://wiki.qemu.org/Features/QAPI]().

From [the original patch series](https://www.mail-archive.com/qemu-devel@nongnu.org/msg55267.html):

> Goals of QAPI
> 
> 1) Make all interfaces consumable in C such that we can use the
>    interfaces in QEMU
> 
> 2) Make all interfaces exposed through a library using code
>    generation from static introspection
> 
> 3) Make all interfaces well specified in a formal schema

From [the documentation](https://github.com/qemu/qemu/blob/master/docs/qapi-code-gen.txt):

> QAPI is a native C API within QEMU which provides management-level
> functionality to internal and external users. For external
> users/processes, this interface is made available by a JSON-based wire
> format for the QEMU Monitor Protocol (QMP) for controlling qemu, as
> well as the QEMU Guest Agent (QGA) for communicating with the guest.
> The remainder of this document uses "Client JSON Protocol" when
> referring to the wire contents of a QMP or QGA connection.
> 
> To map Client JSON Protocol interfaces to the native C QAPI
> implementations, a JSON-based schema is used to define types and
> function signatures, and a set of scripts is used to generate types,
> signatures, and marshaling/dispatch code. This document will describe
> how the schemas, scripts, and resulting code are used.

See also:
* KVM Forum 2011 talk by Anthony Liguori: _"Code Generation for Fun and Profit"_ ([slides](http://www.linux-kvm.org/images/e/e6/2011-forum-qapi-liguori.pdf), [video](https://youtu.be/YIO34fz8ans))


## Visitor API

QAPI includes an API to define and use
[visitors](https://en.wikipedia.org/wiki/Visitor_pattern) for the
QAPI-defined data types. Visitors are the mechanism used to
serialize QAPI data to/from the external world (e.g. through QMP, the
command-line, or config files).

From [its documentation](https://github.com/qemu/qemu/blob/master/include/qapi/visitor.h):

> The QAPI schema defines both a set of C data types, and a QMP wire
> format.  QAPI objects can contain references to other QAPI objects,
> resulting in a directed acyclic graph.  QAPI also generates visitor
> functions to walk these graphs.  This file represents the interface
> for doing work at each node of a QAPI graph; it can also be used
> for a virtual walk, where there is no actual QAPI C struct.
>
> There are four kinds of visitor classes: input visitors (QObject,
> string, and QemuOpts) parse an external representation and build
> the corresponding QAPI graph, output visitors (QObject and string) take
> a completed QAPI graph and generate an external representation, the
> dealloc visitor can take a QAPI graph (possibly partially
> constructed) and recursively free its resources, and the clone
> visitor performs a deep clone of one QAPI object to another.  While
> the dealloc and QObject input/output visitors are general, the string,
> QemuOpts, and clone visitors have some implementation limitations;
> see the documentation for each visitor for more details on what it
> supports.  Also, see visitor-impl.h for the callback contracts
> implemented by each visitor, and docs/qapi-code-gen.txt for more
> about the QAPI code generator.


## The End

Although large, this list is incomplete. In the near future, I
plan to write about QAPI, QOM, and QemuOpts, and how they work
(and sometimes don't work) together.

Most of the abstractions above are about _data modeling_, in one
way or another. That's not a coincidence: one of the things I
want to write about are how some times those data abstractions
have conflicting world views, and the issues resulting from that.



**Feedback wanted:** if you have any correction or suggestion to this
list, please send your comments. You can use the
[GitHub page for the post](https://github.com/ehabkost/habkost.net/blame/master/habkost-net/_posts/2016-11-28-introduction-qemu-apis.markdown)
to send comments or suggest changes, or just [e-mail me](mailto:ehabkost@redhat.com).
