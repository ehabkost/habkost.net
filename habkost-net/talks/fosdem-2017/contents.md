# QEMU internal APIs

Eduardo Habkost &lt;ehabkost@redhat.com&gt;

Note:
Hello, my name is Eduardo. I work for Red Hat at the KVM team,
mostly on QEMU.



# Contents

* An overview of QEMU internals
* How it works
* What are the challenges

Note:
Contents of this talk


## *Not* included:

* The <i>right</i> way
* Solutions to issues

Note:
If I were talking only to QEMU developers, I would probably
be presenting suggestions to fix some issues and change how things
work.
Here I will **try** to talk about how things work, show what
are the existing challenges, but not try to present solutions.
This is an invitation for discussion.


Incomplete

(time is limited)



# Context


<i>"QEMU is a generic and open source machine emulator and virtualizer."</i>

Note:
Large set of use cases. It can be used by a lone developer testing
a OS image for a small embedded system, but also as the userspace
component of huge KVM or Xen VMs running in production systems.

Some of the challenges we see here come from this conflict
of goals.


## QEMU modes:

* `qemu`: user-mode emulation
* `qemu-system`: system emulation

Note:
user-mode emulation can run binaries compiled for other
architectures, no hardware emulation. Available for Linux and BSD.

System emulation can emulate a complete machine.


## (CPU) <i>Accelerators</i>

* TCG (emulator)
* KVM
* Xen

Note:
Accelerators are how the Xen and KVM stuff inside QEMU
is called. They basically change how CPUs are emulated,
while keeping the existing hardware emulation code.



## Interfaces

* Command-line
* Monitor (command interface) (for humans)
* QMP (QEMU Monitor Protocol) (for machines)

Note:
* TODO: Image: QEMU command-line
* TODO: Image: QEMU monitor
* TODO: Image: QMP



# QEMU internals


## Things to handle:

* Configuration options
* QMP
* Device configuration
* Device state (including migration)
* Backend configuration
* <i>etc.</i>

Note: This is an incomplete list of things QEMU needs to handle
internally. The APIs I will talk about are used to solve one
or more of these problems.


## Internal APIs


## APIs: QemuOpts (2009)

* Parsing and storage of command-line configuration options
* Config file support
* Few basic data types
* Flat data model

Note:
* TODO: Image: command-line options
* TODO: Image: config file



## APIs: qdev (2009)

* Device tree
* Single API to create, configure and plug devices
* Bus/device tree
* Property system, introspection
* Reference counting
* Rebuilt on top of QOM (2011)

Note:
* TODO: Image: -device command-line
* TODO: Image: info qtree



## APIs: QMP (2009)

* JSON handling
* Dispatching commands
* Data representation: QObject


## APIs: QObject (2009)

Same data types as JSON:

* string
* integer
* float
* dictionary
* list
* bool
* null


## APIs: QOM (2011)

* QEMU Object Model
* Classes, object instances, properties, introspection

(Don't confuse with QObject)


## QOM: user-visible usage

* qdev
* backend objects
* *accelerator* configuration (TCG, KVM, Xen)
* machine-type system
* CPU configuration system


## QOM: internal usage

* MemoryRegions
* IRQs
* S390 IOMMU?
* <i>etc.</i>

Note:
QOM was used to build or rebuild:


### QOM: internal vs. external
* Unclear:
  * What should be user-visible
  * What should be a stable interface
* Types can be hidden from the user (`no_user`)
* Properties can't be hidden
  * Today's convention: <b>"x-"</b> prefix



## APIs: QAPI (2011)

* Formal schema for interfaces
* Mostly for QMP commands
* Some command-line options
* Visitors
* Generated code for: serialization, dispatching QMP commands

Note:
* TODO: Image: QAPI schema



# Issues


## Issue: Data types

* QMP (QObject) == QAPI (yay)
* QAPI != QOM != QemuOpts

Note:
* TODO: Table: data types comparison.



## Issue: Introspection & Data Flow


## Steps

* Compile time (static)
* Runtime:
  * Event: Initialization (static)
    * static var
    * hardcoded at main()
    * QOM/qdev type registration
    * QOM/qdev class_init
    * QOM/qdev instantiation
  * Event: Monitor is available
  * Event: machine creation
  * Event: machine is running

* TODO: Table: information availability:

Note:
Steps:

Data items:
* qdev type list
* QOM properties
* QemuOpts sections
* QAPI schema
* machine-type list
* machine-type defaults
* machine-type devices

* TODO: Image/table: showing data flow on top of the table above.

Note:
Why is this a problem: introspection.

Lots of data is static, but becomes available very late at runtime.
Some data is static, but never becomes available to the outside.
Some data is static in practice, but treated like it's dynamic.
Some data is dynamic/configurable in practice, but defaults are supposed to be static, and are hard to discover.




## Issue: data translation


## Can translate:
* QemuOpts ⇒ QAPI data structures
* QemuOpts ⇒ QOM


## Translation issues:
* Incompatible data-types
* Data unavailable at the right time


## Not translated:
* <i>anything</i> ⇒ QAPI schema
* QOM ⇒ <i>almost anything</i>

Note:
* TODO: examples?



## Issue: overlap and duplication

* APIs providing similar features
* Some code is not shared


## Duplication example:
* Parsing code

Note:
* TODO: image for parsing code


## Overlap examples:

Data representation: QemuOpts vs QOM vs QAPI

* OK when translation is possible
* A dilemma when translation is not possible
* Affects design of external interfaces

Note:
* TODO: count how many

* TODO: examples

Example: Commplex interface based on QOM properties can't benefit
from QAPI schema.


## Issue: interface documentation

* QAPI schema: <b>comprehensive</b>
* QemuOpts: <b>brief</b>
* QOM types and properties: <b>almost none</b>




# Conclusion


Q: What should we do?

A:  Propose and discuss solutions on qemu-devel.  ;)



## Pointers:

* http://habkost.net/talks/fosdem-2017/

Note:
* TODO: add URL
