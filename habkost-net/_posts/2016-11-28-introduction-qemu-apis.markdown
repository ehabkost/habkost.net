---
layout: post
title:  An incomplete list of QEMU APIs
date:   2016-11-28 22:20:00 -0200
categories: virt
slug: incomplete-list-of-qemu-apis
---

Having seen many people (including myself) feeling confused by
some of QEMU's internal APIs when reviewing and contributing code
to QEMU, I am trying to document things I learned about some of
QEMU's abstraction and APIs.

*Feedback wanted:* 

## QemuOpts

[Introduced in 2009](https://github.com/qemu/qemu/commit/e27c88fe9eb26648e4fb282cb3761c41f06ff18a).
It is a very old data abstraction in QEMU. As the original commit
message describes it, it _stores device parameters in a better
way than unparsed strings_. It is still used by configuration and
command-line parsing code.

Making QemuOpts work with the other newer abstractions below
(e.g. QOM and QAPI) may be painful. Sometimes you can't run
away from QemuOpts, sometimes you can pretend it is not there.
But if you are dealing with QEMU configuration or command-line
parameters, it is always there.

## qdev

qdev [was added to QEMU in 2009](https://github.com/qemu/qemu/commit/aae9460e244c7abe70b72ff374b3aa102bb09691).
I couldn't find clear pointers to its origins and goals on qemu-
devel or source code commits.

qdev manages the QEMU _device tree_, based on a hierarchy of
_buses_ and _devices_.

Some may argue that qdev was _replaced_ by QOM, others may
describe it as being _built on top_ of QOM. Either way you
describe it, there are `qdev-*.[ch]` files and `qdev_*()`
functions living inside QEMU that take care of device state and
device tree management.

## QOM

QOM is short for _QEMU Object Model_ and was [introduced in 2011](https://github.com/qemu/qemu/commit/2f28d2ff9dce3c404b36e90e64541a4d48daf0ca).
It is heavily documented on [its header file](https://github.com/qemu/qemu/blob/master/include/qom/object.h).
It started as a generalization of qdev.

From its documentation:

> The QEMU Object Model provides a framework for registering user creatable
> types and instantiating objects from those types.  QOM provides the following
> features:
>
>  - System for dynamically registering types
>  - Support for single-inheritance of types
>  - Multiple inheritance of stateless interfaces


## VMState

VMState was [introduced in 2009](https://github.com/qemu/qemu/commit/9ed7d6ae0fe7abb444c65caaadb5ef307df82c60).
It was added to change the device state saving/loading (for
savevm and migration) from ad-hoc coding to a table-based
approach.

From the original commit:

> New VMstate save/load infrastructure
> 
> This patch introduces VMState infrastructure, to convert the save/load
> functions of devices to a table approach.  This new approach has the
> following advantages:
> - it is type-safe
> - you can't have load/save functions out of sync
> - will allows us to have new interesting commands, like dump <device>, that shows all its internal state.
> - Just now, the only added type is arrays, but we can add structures.
> - Uses old load_state() function for loading old state.


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

In [the original patch series](https://www.mail-archive.com/qemu-devel@nongnu.org/msg55267.html):

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


## Visitors

QAPI includes an API to define and use [visitors](https://en.wikipedia.org/wiki/Visitor_pattern)
for the QAPI-defined data types.

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


## QMP

QMP is the _QEMU Machine Protocol_. [Introduced in 2009](https://github.com/qemu/qemu/commit/9b57c02e3e14163b576ada77ddd1d7b346a6e421). From [its documentation](https://github.com/qemu/qemu/blob/master/docs/qmp-intro.txt):

> The QEMU Machine Protocol (QMP) allows applications to operate a
> QEMU instance.
> 
> QMP is [JSON](http://www.json.org) based and features the following:
> 
> - Lightweight, text-based, easy to parse data format
> - Asynchronous messages support (ie. events)
> - Capabilities Negotiation
> 
> For detailed information on QMP's usage, please, refer to the following files:
> 
> * qmp-spec.txt      QEMU Machine Protocol current specification
> * qmp-commands.txt  QMP supported commands (auto-generated at build-time)
> * qmp-events.txt    List of available asynchronous events


## Feedback wanted

I would
