# QEMU internal APIs
## How abstractions inside QEMU (don't) work together
Eduardo Habkost &lt;ehabkost@redhat.com&gt;

Note: Hello, my name is Eduardo. I work for Red Hat at the KVM team,
mostly on QEMU. I will talk about the internal APIs in QEMU.

* TODO: enums
* TODO: lists on QemuOpts
* TODO: MORE EXAMPLES!!!
* TODO: danpb work on qemuopts/qapi
* TODO: slide numbers!
* TODO: make introduction shorter
* TODO: mention HMP acronym


# Contents

* Context: QEMU features and interfaces
* Overview of some internal QEMU APIs
* Issues and challenges

Note: These are the contents of this talk. I will first explain a
little bit of what QEMU does, then present of the internal APIs
QEMU has, and how they are used. Then I will talk about the
existing issues and challenges we have when we try to make those
APIs work together.


## *Not* included:

* The <i>right</i> way to do something
* Solutions to issues

Note:

If I were talking only to QEMU developers, I would probably be
suggesting how to fix some issues and change how things work. We
often see this sort of talk on KVM Forum, for example.

Here I will **try** to not present solutions or suggest how to
fix things. This is an invitation for discussion, only.


## Incomplete

* Time is limited
* Knowledge is limited

Note: Keep in mind that this talk is incomplete: we do not cover
every single internal QEMU API. That's because we don't have much
time and I lack the knowledge about some other APIs.


# Context

Note: Let's see some of the context: what QEMU does and needs to
do.


> "QEMU is a generic and open source machine emulator and virtualizer."
> 
> &mdash; http://qemu.org/

Note:

This is how QEMU is described at qemu.org. Being an "emulator"
and "virtualizer", QEMU has a large set of use cases. It can be
used by a lone developer testing a OS image for a small embedded
system, but also as the userspace component of huge KVM or Xen
VMs running in production systems. Some of the challenges we see
here come from this conflict of goals.


## QEMU modes:

* `qemu-*` &mdash; user-mode emulation
* `qemu-system-*` &mdash; system emulation

Note:

QEMU has two main modes of operation. user-mode emulation is
available for Linux and BSD, it can run binaries compiled for
other architectures, no hardware emulation. System emulation can
emulate a complete machine. System emulation is the mode that
also supports Xen and KVM virtualization.


## (CPU) <i>Accelerators</i>

* KVM
* Xen
* TCG (emulator)

Note: Accelerators are basically how the Xen and KVM stuff inside
QEMU is called. They basically change how CPUs are executed,
while keeping the existing hardware emulation code. TCG is the
original CPU emulator code from QEMU.


## Interfaces

* Command-line
* Config files
* Monitor (command interface) (for humans)
* QMP (QEMU Monitor Protocol) (for machines)

Note:

QEMU has multiple interface to interact with the outside world.
The main ones are: the command-line and the monitor. There are
two monitor modes: one for humans, and one for machines called
QMP.

* TODO: Image: QEMU command-line
* TODO: Image: QEMU monitor
* TODO: Image: QMP



# QEMU Internals


## Things to handle:

* Configuration options
* Monitor commands
* Device configuration
* Device state (including migration)
* Backend configuration
* <i>etc.</i>

Note: This is an incomplete list of things QEMU needs to handle
internally. The APIs I will talk about are used to solve one or
more of these problems. QEMU needs to keep track of configuration
options, handle monitor commands, keep track of device
configuration and device state (that's the frontend part), and
backend configuration.


## Internal APIs

Note: let's talk about the internal APIs that let QEMU do its job.


## API: QemuOpts (2009)

* Parsing and storage of command-line configuration options
* Config file support
* Few basic data types
* Flat data model

Note:

QemuOpts is an old API introduced in 2009, to handle parsing of
command-line options and config files. It is used both to parse
the config files and as a configuration option storage system. It
has very few basic data types, and has a flat data model.

* TODO: Image: command-line options
* TODO: Image: config file


## QemuOpts usage

* Parsing of most command-line options
* `-readconfig`, `-writeconfig` support
* Internal storage of config options

Note: QemuOpts is used to parse most of the command-line options,
as a storage system for config options, and to read and write VM
configuration to config files. Note that as config options can be
exported, QEMU tries to store all configuration options inside
QemuOpts so it can be exported later.


## API: qdev (2009)

* Bus/device tree
* Single API to create, configure and plug devices
* Property system, introspection
* Reference counting

Note:

qdeve is the bus and device tree system hierarchy system. It
allows QEMU to provide a unified interface to create, configure
and plug devices. It means having generic internal and external
APIs to handle devices. It provides a property system that allow
introspection of all device configuration.

* TODO: Image: -device command-line
* TODO: Image: info qtree


## qdev usage

* Every device emulated by QEMU
* `-device`, `device_add`
* Introspection of device tree (e.g. `info qtree`)
* Rebuilt on top of QOM (2011)

Note: qdev is quite successful: it is used to configure every
device emulated by QEMU, to provide a generic interface to plug
devices both on the command-line and through monitor commands
(for device hotplug and hot unplug), and to introspect device
configuration. When we introduced QOM, the QEMU Object Model in
2011, the qdev abstractions were kept but rebuilt on top of QOM.


## API: QMP (2009)

* JSON-based monitor protocol

Note: QMP is the machine-friendly monitor protocol. It is based
on JSON.


## QMP usage

* QEMU ⇔ management software communication
* QEMU Guest Agent
* Data representation: QObject

Note: QMP is used for most runtime communication between QEMU and
management software. The same code is also reused for
communication between QEMU and QEMU Guest Agent inside VMs. It
also originated the QObject abstractions for representing data
internally.


## API: QObject (2009)

* Created for QMP
* Same data types as JSON: string, integer, float, dictionary, list, bool, null
* Reference counting

Note: QObject was created for QMP and was successfully reused by
other systems later. It can represent all the data types
supported by JSON, and implements a reference counting system.


## QObject usage

* QMP
* QAPI-based interfaces
* Internal data structures

Note: In addition to QMP, QObject was reused later by QAPI and
for representing some internal data structures.


## API: QAPI (2011)

* Formal schema for interfaces
* Visitor API
* Generated code for: serialization, dispatching QMP commands

Note:

QAPI is a system for defining QEMU external interfaces. It uses a
JSON-like language for defining data structures and interfaces
(like QMP commands). It provides a visitor API for implementing
data input, output and conversion, and generates visitor code,
code for serialization, and for dispatching QMP commands.

* TODO: Image: QAPI schema


## QAPI usage

* All QMP commands
* Some command-line options

Note: QAPI is successfully used to define and dispatch all QMP
commands, and to define and parse a few command-line options.
Every single data structure and QMP command has very detailed
documentation. It is a great system.


## API: QOM (2011)

* QEMU Object Model
* Reference counting
* Type hierarchy

<span style="font-size: smaller;">(Don't confuse with QObject)</span>

Note: QOM is the QEMU Object Model, do not confuse it with
QObject. It started as a generalization of qdev and has lots of
interesting features that would deserve its own talk, so I won't
try to cover all of them.


## QOM usage

* qdev (`-device`, `device_add`)
* backend objects (`-object`)
* *accelerator* configuration (TCG, KVM, Xen)<br>(`-machine accel=...`)
* machine-type system (`-machine`)
* CPU configuration system (`-cpu`, `query-cpu-*`)
* Manipulation of object/device tree through QMP
* Some internal data-structures (MemoryRegions, IRQs)

Note: QOM is also quite successful. Most of the existing qdev
code is just a wrapper around QOM abstractions. QOM used to build
a generic system for creating and configuring backend objects. We
also ported multiple subsystems to be built on top of QOM,
including the machine-type system, accelerator configuration, and
the CPU configuration system. QOM is also used for some internal
data structures like MemoryRegions and IRQs.


## QOM tree manipulation

* QOM device/object tree can be manipulated through QMP
* Not very popular in practice

Note: The QOM object tree is exposed to the outside through QMP
commands. In theory this could be used to provide generic
interfaces to configure and manipulate devices and objects
without introducing new specialized QMP commands. But in practice
we normally add new commands and structs in the QAPI schema
instead of just letting new features be implemented through pure
QOM manipulation. There are multiple reasons for that, and I hope
some of them will be clear in the rest of this talk.


### QOM: internal vs. external

* Unclear:
  * What should be user-visible
  * What should be a stable interface
* Types can be hidden from the user (`no_user`)
* Properties can't be hidden
  * Today's (undocumented) convention: <b>"x-"</b> prefix

Note: one problem with QOM currently is that it is used both to
implement internal and external interfaces, and sometimes there's
not a clear line dividing them. QOM types can be easily hidden
from the user, but properties that are intended for external
usage are still visible to the outside, meaning they can be read
through QMP and configured through QMP or the command-line. This
makes it risky to change property semantics, because we don't
know if some other software is relying on it. We have been trying
to use a naming convention to indicate which properties are
experimental or intended for internal usage only.



# Issues


## Data types

<table>
  <tr>
    <th>Type</th>
    <th>int</th>
    <th>float</th>
    <th>bool</th>
    <th>string</th>
    <th>list</th>
    <th>dict</th>
  </tr>
  <tr>
    <td>QemuOpts</td>
    <td>✔</td>
    <td></td>
    <td>✔</td>
    <td>✔</td>
    <td></td>
    <td></td>
  </tr>
  <tr>
    <td>qdev</td>
    <td>✔</td>
    <td></td>
    <td>✔</td>
    <td>✔</td>
    <td></td>
    <td></td>
  </tr>
  <tr>
    <td>QObject&nbsp;&amp;&nbsp;QAPI</td>
    <td>✔</td>
    <td>✔</td>
    <td>✔</td>
    <td>✔</td>
    <td>✔</td>
    <td>✔</td>
  </tr>
  <tr>
    <td>QOM</td>
    <td>✔</td>
    <td>✔</td>
    <td>✔</td>
    <td>✔</td>
    <td style="color: gray;">✔?</td>
    <td style="color: gray;">✔?</td>
  </tr>
</table>

Note: Most of the APIs I have talked about involve some type of
data representation. This is a summary of data types supported by
some of those APIs. QObject and QAPI have the most powerful type
systems. QOM is almost as powerful as QAPI, but not exactly.


## Issue: runtime data translation

* Some APIs have similar abstractions.
* Translation can be a *compatibility mechanism* while porting code.

Note: Sometimes similar tasks can be implemented using different
APIs. Translation can be a compatibility mechanism while code is
still being ported to a new system.


<style type="text/css">
table.abstractions { font-size: smaller; }
table.abstractions th {font-weight:bold;vertical-align:top}
.static { background-color: #999; color: #111; }
.gray { background-color: #778; color: #111; }
.runtime { background-color: #336; }
.legend { display: inline-block; width: 1em; height: 1em;}
</style>
<table class="abstractions">
  <tr>
    <th>QemuOpts</th>
    <th>qdev</th>
    <th>QOM</th>
    <th>QObject</th>
    <th>QAPI</th>
  </tr>
  <tr>
    <td class="static">QemuOptsList</td>
    <td class="static">type</td>
    <td class="static">class</td>
    <td class="static">-</td>
    <td class="static">schema struct</td>
  </tr>
  <tr>
    <td class="static">QemuOptDesc</td>
    <td class="static">property</td>
    <td class="gray">property</td>
    <td class="static">-</td>
    <td class="static">schema field</td>
  </tr>
  <tr>
    <td class="static">option default</td>
    <td class="static">property default</td>
    <td class="gray">property default</td>
    <td class="static">-</td>
    <td class="static">-</td>
  </tr>
  <tr>
    <td class="runtime">QemuOpts</td>
    <td class="runtime">device</td>
    <td class="runtime">instance</td>
    <td class="runtime">QDict</td>
    <td class="runtime">C struct</td>
  </tr>
  <tr>
    <td class="runtime">QemuOpt</td>
    <td class="runtime">property value</td>
    <td class="runtime">property value</td>
    <td class="runtime">QObject</td>
    <td class="runtime">C field</td>
  </tr>
</table>

<span class="static legend">  </span> static data &emsp;
<span class="runtime legend">  </span> runtime data

Note:

Some of the APIs we have talked about have equivalent data
structures and abstractions. I have tried to show their
equivalencies on this table.

Most of the APIs shown here have some concept of "type": it can
be a class, a config group, or a struct defined in the QAPI
schema. Most of them define a set of properties that can be read
or written on objects of that type. They might also define a
default value for each property.

Here we can see the first differences: QOM is more flexible about
how properties are defined, and the properties and their defaults
are not 100% static.

Note, however that "static data" here means "defined statically
in the source code". It doesn't mean it can be easily extracted
from the source code at build time, or immediately acessible to
running code. This is another issue I plan to talk about if time
allows.


## Can translate:
* QAPI ⇔ QObject
* qdev ⇒ QOM (qdev *is* QOM)
* QemuOpts ⇒ QAPI structs
* QemuOpts ⇒ QOM

Note:

These are some cases where we can successfully translate data at runtime.

QAPI and QObject is an example where translation is perfect and
seamless. QAPI was written with that translation in mind, and
this is done by automatically generated code.

qdev is another successful example. As most of qdev is a wrapper
around QOM, most of qdev data is automatically qcessible using
QOM interfaces.

We also have wrappers to translate QemuOpts data to QAPI and QOM.
It is not perfect, but works for many cases.


## <i>anything</i> ⇒ QAPI schema

Not possible by definition<br>(QAPI schema is a static source code file)

Note:
Now, some things we *do not translated at runtime:

The QAPI schema is defined a single JSON file on the source code.
*By definition* we can't translate other abstractions to it.


## <i>anything</i> ⇒ QemuOpts

* Not translated
* Limited QemuOpts data model
* Not a problem in practice

Note:
Despite having mechanisms to convert data from QemuOpts, the
opposite way is not possible. The main reason is that the
QemuOpts data model is very limited. But this is normally not a
problem because except for `-writeconfig` we don't have anything
that relies on *reading* QemuOpts to work.


## Other "schema" data
(QAPI schema, QOM type hierarchy, config groups)

* No mechanisms for translation
* QOM/QAPI dilemma when designing new interfaces<br>
* Normally we choose QAPI
  * Exceptions: CPU config, `device_add` and `object-add` options
* Exception: a few QemuOpts config groups<br>
  (property descriptions are optional)

Note:

We also don't translate most of the "schema" data. By "schema" I
mean type hierarchy information and property descriptions. This
is a problem when defining new interfaces, because we need to
choose between descripting the new interface using the QAPI
schema or QOM properties. Duplicating the data model in QOM and
QAPI is also possible, but I am not aware of any case where we
did that.

We normally choose QAPI on those cases, but not all of them. One
example of exception is the CPU model probing and configuration
system, and `-device` and `device_add` arguments.

There are a few exceptions when QemuOpts is involved: QemuOpts
property descriptions are optional, so we can let QemuOpts parse
all options but get them validated by QAPI visitors or QOM
property setters.

Translating QAPI runtime data to QOM should be possible, in
theory. But as we don't have schema translation mechanisms, this
means we would need to duplicate the same definitions in the QAPI
schema and on the QOM property registration code.

<!-- ## Translation issues: -->
<!-- * Incompatible data-types -->
<!-- * Data unavailable at the right time -->


<!-- ## Issue: overlap and duplication -->
<!--  -->
<!-- * APIs providing similar features -->
<!-- * Some code is not shared -->
<!--  -->
<!--  -->
<!-- ## Duplication example: -->
<!-- * Parsing code -->
<!--  -->
<!-- Note: -->
<!-- * TODO: image for parsing code -->
<!--  -->
<!--  -->
<!-- ## Overlap example: -->
<!--  -->
<!-- Data representation: QemuOpts vs QOM vs QAPI -->
<!--  -->
<!-- * OK when translation is possible -->
<!-- * Interface design dilemmas when translation is not possible -->
<!-- * Affects design of external interfaces -->
<!--  -->
<!-- Note: -->
<!-- * TODO: count how many -->
<!--  -->
<!-- * TODO: examples -->
<!--  -->
<!-- Example: Commplex interface based on QOM properties can't benefit -->
<!-- from QAPI schema. -->
<!--  -->
<!--  -->
## Issue: interface documentation

* QAPI schema: <b>comprehensive</b>
* QemuOpts: <b>brief</b>
* QOM types and properties: <b>almost none</b>


## Issue: Introspection & data availability


<!-- ## Steps -->
<!--  -->
<!-- * Compile time (static) -->
<!-- * Runtime: -->
<!--   * Event: Initialization (static) -->
<!--     * static var -->
<!--     * hardcoded at main() -->
<!--     * QOM/qdev type registration -->
<!--     * QOM/qdev class_init -->
<!--     * QOM/qdev instantiation -->
<!--   * Event: Monitor is available -->
<!--   * Event: machine creation -->
<!--   * Event: machine is running -->
<!--  -->
<!-- Note: TODO: Table: information availability  -->
<!--  -->
<!--  -->
<!-- ## Data items -->
<!--  -->
<!-- * qdev type list -->
<!-- * QOM properties -->
<!-- * QemuOpts sections -->
<!-- * QAPI schema -->
<!-- * machine-type list -->
<!-- * machine-type defaults -->
<!-- * machine-type devices -->
<!--  -->
<!-- Note: -->
<!-- * TODO: Image/table: showing data flow on top of the table above. -->
<!-- * Why is this a problem: introspection. -->
<!--  -->
<!--  -->
### Static data treated like dynamic data

* QOM type hierarchy
* QOM property lists
* machine-type default options
* machine-type default devices/buses

Note: there is some data that is defined statically on the source
code, but is treated by the system like it's dynamic data. The
QOM type hierarchy and properties are registered dynamically, but
in practice it's static data. Defaults for machine-types are
defined statically, but also treated like dynamic data.


### Dynamic data whose static defaults are hard to discover
* machine-type default options
* machine-type default devices/buses


### Static data that never becomes available to the outside
* Some machine-type behavior



# Not Covered

* Migration system (VMState, savevm handlers)
* Main loop
* Char devices
* Block layer
* Coroutines

Note: Things not covered by this talk, but could be explored further.


# Conclusion


Q: What should we do?

A: Propose and discuss solutions on qemu-devel.  ;)



## More

http://habkost.net/talks/fosdem-2017/

Note:
* TODO: add URL
