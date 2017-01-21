---
layout: post
---

> Hello, my name is Eduardo. I work for Red Hat at the KVM team,
> mostly on QEMU, that's a userspace component of KVM.

## Contents

> Contents of this talk

* An overview of QEMU internals
* How it works
* What are the challenges
* Not how to fix it
* Incomplete (time is limited)

> If I were talking only to QEMU developers, I would probably
> be presenting suggestions to fix some issues and change how things
> work.
> Here I will **try** to talk about how things work, show what
> are the existing challenges, but not try to present solutions.
> This is an invitation for discussion.

## QEMU

"QEMU is a generic and open source machine emulator and virtualizer."

"QEMU is a generic and open source machine **emulator** and **virtualizer**."

> Large set of use cases. It can be used by a lone developer testing
> a OS image for a small embedded system, but also as the userspace
> component of huge KVM or Xen VMs running in production systems.

> Some of the challenges we see here come from this conflict
> of goals.

## QEMU: overview

* `qemu` user-mode emulation
* `qemu-system-*` system emulation

* TCG emulator
* KVM
* Xen

> user-mode runs binaries for other architectures.
> I won't explain how QEMU does everything, 

## QEMU: interfaces

* Command-line
* Monitor (comand intrface) (for humans)
* QMP (QEMU Monitor Protocol) (for machines)

> Image: QEMU command-line
> Image: QEMU monitor
> Image: QMP

## QEMU: internals

> Some tasks that are relevant for this talk:

* Keeping track of configuration options
* Handling QMP
* Keeping track of devices:
  * Configuration
  * State (including migration)
* machine-type system

## APIs: QemuOpts

* 2009
* Parsing and storage of command-line configuration options
* Config file support
* Few basic data types
* Flat data model

> Image: command-line options
> Image: config file

## APIs: qdev

* 2009
* Device tree
* Single API to create, configure and plug devices
* Bus/device tree
* Property system, introspection
* Reference counting
* Rebuilt on top of QOM (next slide)

> Image: -device command-line
> Image: info qtree

## APIs: QMP

* 2009
* QMP and QObject
* QObject is not QOM

## APIs: QOM

* 2011
* Object Model
* Classes, object instances, properties, introspection
* Not just qdev (device emulation, frontend), but also backend
  objects
* **Conflict:** internal usage vs user-visible stuff
  * Not clear:
    * What should be user-visible
    * What should be a stable API
  * Types can be flagged no_user
  * Properties can't be flagged
  * Today's convention: "x-" prefix

## APIs: QOM usage

> QOM was used to build or rebuild:

* User-visible:
  * qdev
  * backend objects
  * *accelerator* configuration (TCG, KVM, Xen)
  * machine-type system
  * CPU configuration system
* A few internal: MemoryRegions, IRQs, S390 IOMMU (?)

## QAPI:

* 2011
* Interfaces specified in a formal schema
* Used mostly for QMP commands, but used for some command-line
  options.
* Visitors
* Generated code for: seralization, dispatching QMP commands.

> Image: QAPI schema

## Issue: data types

* QMP (QObject) == QAPI (yay)
* QAPI != QOM != QemuOpts

> Table: data types comparison.


## Issue: introspection & time

> Steps:
> 
> * Compile time (static)
> * Runtime:
>   * Event: Initialization (static)
>     * static var
>     * hardcoded at main()
>     * QOM/qdev type registration
>     * QOM/qdev class_init
>     * QOM/qdev instantiation
>   * Event: Monitor is available
>   * Event: machine creation
>   * Event: machine is running
> 
> Table: information availability:
> * qdev type list: 
> * QOM properties
> * QemuOpts sections
> * QAPI schema
> * Device list for a machine-type

> Why is this a problem: introspection.

> Lots of data is static, but becomes available very late at runtime.
> Some data is static, but never becomes available to the outside.
> Some data is static in practice, but treated like it's dynamic.
> Some data is dynamic/configurable in practice, but defaults are supposed to be static, and are hard to discover.

> Image/table: showing data flow on top of the table above.


## Issue: data translation

* Some data from different systems could be translated
* Some are:
  * QemuOpts to QAPI data structures
  * QemuOpts to QOM
* Some are not:
  * QOM to QAPI
* Beware of data-type issues
* Beware of duplication of parsing code


## Issue: documentation

* QAPI schema (incl. QMP commands) is well documented
* QemuOpts is sometimes documented
* QOM types and properties are mostly not documented


## Conclusion

What should we do?

Send messages to qemu-devel and fix stuff.  ;)


## Pointers:

* http://habkost.net/???
