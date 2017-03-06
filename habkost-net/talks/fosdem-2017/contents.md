# QEMU internal APIs
## How abstractions inside QEMU (don't) work together
Eduardo Habkost &lt;ehabkost@redhat.com&gt;

<!-- <p style="font-size: 75%; border-top: solid 1px #444; padding-top: 1em">Slides available at:<br> -->
<!-- http://habkost.net/talks/fosdem-2017/</p> -->

Note: Hello, thank you for coming. My name is Eduardo. I work for
Red Hat at the KVM team, mostly on QEMU. I will talk about the
internal APIs in QEMU.

* TODO: danpb work on qemuopts/qapi



# Contents

* Context: QEMU features and interfaces
* Overview of some internal QEMU APIs
* Interaction between different abstractions

Note: These are the contents of this talk. I will first explain a
little bit of what QEMU does, then present some of the internal
APIs used inside QEMU to perform its job. After that, I will talk
about how those abstractions work and don't work together.


## *Not* included:

* The <i>right way</i> to do something
* Solutions to issues
* Every single API in QEMU

Note:

Now, this is what's **not** included in this talk:

I will **try** to not present solutions or suggest how to fix
issues. This is an introductory talk. I hope it will generate
interesting discussion later, though.

Also, keep in mind that this talk won't cover every single
internal API in QEMU. I am trying to cover what I feel are the
most important ones for QEMU developers, but that's just my
perception.



# Context

Note: Let's see some context first: what QEMU does and what it
needs to do to do its job. But first I would like to ask a few
questions:

* How many people here know what QEMU is?
* How many people use QEMU?
* How many people use KVM?
* How many people use Xen?


> "QEMU is a generic and open source machine emulator and virtualizer."
> 
> &mdash; http://qemu.org/

Note:

What is QEMU and what it does? QEMU's web site says: <i>"QEMU is
a generic and open source machine emulator and virtualizer"</i>.
I won't try to explain this in detail, but the summary is: QEMU
can be used in a lot of ways as an emulator, and it is an
important component when running Virtual Machines using KVM or
Xen virtualization.


## External Interfaces

Note: QEMU has multiple interface to interact with the outside
world. The main ones are:


### Command-line

<pre><code data-trim class="lang-bash">
$ qemu-system-x86_64 -cpu Nehalem -vga cirrus \
      -device e1000,mac=01:02:03:04:05:06     \
      -machine pc-i440fx-2.7,accel=kvm
</code></pre>

Note: the command-line;


### Config files

<pre><code data-trim class="lang-ini">
[device]
  driver = "e1000"
  mac = "01:02:03:04:05:06"

[machine]
  type = "pc-i440fx-2.7"
  accel = "kvm"
</code></pre>

Note: config-files;


### Human Monitor (HMP)

<pre><code data-trim class="lang-none">
QEMU 2.8.50 monitor - type 'help' for more information
(qemu) device_add e1000,mac=01:02:03:04:05:06
(qemu) info network
e1000.0: index=0,type=nic,model=e1000,macaddr=01:02:03:04:05:06
(qemu) info kvm
kvm support: enabled
(qemu) info cpus
* CPU #0: pc=0xffffffff8105ea06 (halted) thread_id=21209
(qemu) 
</code></pre>

Note: the human monitor, which is a command interface for humans
to control QEMU after it has started;


### Machine Monitor (QMP)

<pre><code data-trim class="lang-js">
⇒ { "execute": "device_add",
     "arguments": { "mac": "01:02:03:04:05:06",
                    "driver": "e1000" } }
⇐ { "return": {} }
⇒ { "execute": "query-cpus",
     "arguments": {} }
⇐ { "return": [{ "halted": false, "pc": 133130950,
                  "current": true,
                  "qom_path": "/machine/unattached/device[0]",
                  "thread_id": 22230, "arch": "x86",
                  "CPU": 0 } ] }
⇒ { "execute": "query-kvm",
     "arguments": {} }
⇐ { "return": { "enabled": true, "present": true } }
</code></pre>

Note: and QMP, which is a machine-friendly protocol to
communicate with QEMU, based on JSON.



# QEMU Internals

Note: After this very quick overview of what QEMU does from the
outside, let's look at some of its internals.


## Things to handle:

* Configuration options
* Monitor commands
* Device configuration
* Device state (including migration)
* Backend configuration
* <i>etc.</i>

Note: We can see on this slide an incomplete list of things QEMU
needs to handle internally. Among other things, QEMU needs to
keep track of configuration options, handle monitor commands,
keep track of device configuration, device state, and backend
configuration. Each of the APIs I will talk about is used to
solve one or more of these problems.


## Internal APIs

Note: And here are some of the internal APIs used to perform
those tasks.


## API: QemuOpts (2009)

* Handling of command-line and config file options
* Few basic data types
* Flat data model

Note: QemuOpts is an old API introduced in 2009, to handle
command-line options and config files. It has very few basic data
types, and has a flat data model.


## QemuOpts usage

* <strike>Most</strike> Many command-line options
* Internal storage of config options
* Config file support (`-readconfig`, `-writeconfig`)

Note: QemuOpts is used to parse many of the command-line options.
If we look only at the really relevant command-line options, I
would say it is used to handle **most** of them. Also, even when
a given command-line option is not *parsed* using QemuOpts, it is
still *stored* using QemuOpts, to allow code to support command-
line options and config file options at the same time.


## QemuOpts example
<pre><code data-trim data-noescape class="lang-bash">
$ qemu-system-x86_64 <b>-memory 2G,maxmem=4G</b>
</code></pre>

⇓

<pre><code data-trim data-noescape class="lang-c">
static QemuOptsList qemu_mem_opts = {
    .name = "memory",
    .implied_opt_name = "size",
    .head = QTAILQ_HEAD_INITIALIZER(qemu_mem_opts.head),
    .merge_lists = true,
    <b>.desc = {
        { .name = "size",   .type = QEMU_OPT_SIZE, },
        { .name = "slots",  .type = QEMU_OPT_NUMBER, },
        { .name = "maxmem", .type = QEMU_OPT_SIZE, },
        { /* end of list */ }
    },</b>
};
</code></pre>

Note: Here is a simple example of QemuOpts in action. We can see
a real QEMU command-line, and the declarations in the code that
make it possible. The most relevant thing here is the **desc**
field, containing the list of supported options for the `-memory`
option.


## API: qdev (2009)

* Bus/device tree
* Single API to create, configure and plug devices
* Property system, introspection
* Rebuilt on top of QOM (2011)

Note: Next API I'll talk about is qdev. qdev is the bus and
device hierarchy system in QEMU. It allows us to provide generic
internal and external interfaces to create, configure, and plug
devices, instead of different APIs and command-line options for
each type of device. It provides a property system for
configuration and introspection of devices.

When we introduced QOM, the QEMU Object Model in 2011, the qdev
abstractions were kept but rebuilt on top of QOM. I will talk
about QOM later.


## qdev usage

* Every device emulated by QEMU
* External generic interfaces (e.g. `-device`, `device_add`)
* Introspection of device tree (e.g. `info qtree`)

Note: qdev is quite successful: it is used internally to create
and configure virtually every device emulated by QEMU. In
addition to internal usage, it provides generic command-line and
monitor interfaces to handle. Its hierarchy and property system
also allows users and management software to peek at what's
inside a running virtual machine.


## qdev Example

<pre><code data-trim data-noescape class="lang-bash">
$ qemu-system-x86_64 <b>-device e1000,mac=12:34:56:78:9a:bc</b>
</code></pre>

⇓

<pre><code data-trim data-noescape class="lang-json">
#define DEFINE_NIC_PROPERTIES(_state, _conf)             \
    DEFINE_PROP_MACADDR("mac",   _state, _conf.macaddr), \
    DEFINE_PROP_VLAN("vlan",     _state, _conf.peers),   \
    DEFINE_PROP_NETDEV("netdev", _state, _conf.peers)

static Property e1000_properties[] = {
    DEFINE_NIC_PROPERTIES(E1000State, conf),
    DEFINE_PROP_BIT("autonegotiation", E1000State,
                    compat_flags, E1000_FLAG_AUTONEG_BIT, true),
    /* [...] */
};
</code></pre>

Note: qdev does many things, so this slide has just a small
sample of the property system, that is one small part of qdev.
Here we can see how configuration properties of a device type
like *e1000* are declared so they can be used on the command-line
using `-device`.


## qdev device tree

<pre><code data-trim data-noescape>
(qemu) info qtree
bus: main-system-bus
  type System
  dev: hpet, id ""
    gpio-in "" 2
    gpio-out "" 1
    gpio-out "sysbus-irq" 32
    timers = 3 (0x3)
    msi = false
    hpet-intcap = 4 (0x4)
    mmio 00000000fed00000/0000000000000400
  dev: kvm-ioapic, id ""
    gpio-in "" 24
    gsi_base = 0 (0x0)
    mmio 00000000fec00000/0000000000001000
  dev: i440FX-pcihost, id ""
    pci-hole64-size = 18446744073709551615 (16 EiB)
    short_root_bus = 0 (0x0)
    bus: pci.0
      type PCI
      dev: PIIX4_PM, id ""
        smb_io_base = 1792 (0x700)
        disable_s3 = 0 (0x0)
        disable_s4 = 0 (0x0)
        s4_val = 2 (0x2)
        acpi-pci-hotplug-with-bridge-support = true
        memory-hotplug-support = true
        addr = 01.3
        romfile = ""
        rombar = 1 (0x1)
        multifunction = false
        command_serr_enable = true
        x-pcie-lnksta-dllla = true
        class Bridge, addr 00:01.3, pci id 8086:7113 (sub 1af4:1100)
        bus: i2c
          type i2c-bus
          dev: smbus-eeprom, id ""
            address = 87 (0x57)
          dev: smbus-eeprom, id ""
            address = 86 (0x56)
          dev: smbus-eeprom, id ""
            address = 85 (0x55)
          dev: smbus-eeprom, id ""
            address = 84 (0x54)
          dev: smbus-eeprom, id ""
            address = 83 (0x53)
          dev: smbus-eeprom, id ""
            address = 82 (0x52)
          dev: smbus-eeprom, id ""
            address = 81 (0x51)
          dev: smbus-eeprom, id ""
            address = 80 (0x50)
</code></pre>

Note: This is how the `info qtree` output looks like. The full
output doesn't fit on the screen, but it contains the full
hierarchy of devices and their properties for the running virtual
machine.


## API: QAPI (2011)

* Formal schema for interfaces
* Visitor API
* Generated code for:
  * C types
  * Serialization
  * Visitors
  * QMP commands and events
  * Interface introspection
  * Documentation

Note: Our next API is QAPI. QAPI is a system for defining QEMU
external interfaces. It uses a JSON-like language for defining
data structures and interfaces (like QMP commands). It provides a
visitor API for implementing data input, output and conversion.
Using the QAPI schema as input, we generated code for things
like: C type declarations, serialization, visitor functions for
each data type on the schema, QMP command dispatching, runtime
introspection of the QAPI schema, and documentation files.


## QAPI usage

* All QMP commands
* Some command-line options

Note: QAPI is successfully used to define and dispatch all QMP
commands, and to define and parse a few command-line options.
Every single data structure and QMP command has very detailed
documentation. It is a great system, and we try to benefit from
QAPI on every new external interface introduced in QEMU.

TODO: check list of internal/non-QMP interfaces or types.


## QAPI Example: `chardev-add`

<pre><code data-trim data-noescape class="lang-json">
⇒ { "execute" : "chardev-add",
     "arguments" : {
         "id" : "bar",
         "backend" : { "type" : "file",
                       "data" : { "out" : "/tmp/bar.log" } } } }
⇐ { "return": {} }
</code></pre>

Note: These are the request and response for a QMP command, as an
example. The command here is `chardev-add`. The request includes
two arguments for the command, "id", and "backend". The response
is empty because this command doesn't return any data after it
finishes.


### `chardev-add` QAPI schema

<pre><code data-trim data-noescape class="lang-js">
{ <span class="symbol">'command'</span>: 'chardev-add',
  'data': { 'id': 'str',
            'backend': 'ChardevBackend' },
  'returns': 'ChardevReturn' }

{ 'union': 'ChardevBackend',
  'data': { 'file': 'ChardevFile',
            'serial': 'ChardevHostdev',
            <i class="comment">[...]</i> } }

{ 'struct': 'ChardevFile',
  'data': { '*in' : 'str', 'out' : 'str', '*append': 'bool' },
  'base': 'ChardevCommon' }
</code></pre>

⇓

<pre><code data-trim class="lang-c">
ChardevReturn *qmp_chardev_add(const char *id,
                               ChardevBackend *backend,
                               Error **errp);
</code></pre>

Note: The QMP command is described in the QAPI schema. This is
the QAPI schema defining `chardev-add`. It defines how the QMP
command input and output should look like. Below, we can see the
function signature of the actual implementation of the command.
Using the QAPI schema as input, we will generate code that will
take care of validating input and calling the `qmp_chardev_add()`
function with a simple C struct as argument.


## API: QOM (2011)

<p style="font-size: smaller">(Don't confuse with QObject)</p>

* QEMU Object Model
* Type hierarchy
* Property system, introspection
* qdev rebuilt on top of it

Note: Last, but not least, we have QOM. QOM is the QEMU Object
Model. Do not confuse it with QObject, which is something else I
am not covering in this talk. It started as a generalization of
qdev and has lots of interesting features that would deserve its
own talk, so I won't try to explain them all. qdev and QOM
sometimes confuse with each other because lots of qdev
abstractions today are simply wrappers around QOM.


## QOM in action

<pre><code data-trim data-noescape class="lang-bash">
$ qemu-system-x86_64 <b>-device</b> e1000,mac=12:34:56:78:9a:bc
</code></pre>
<pre><code data-trim data-noescape class="lang-bash">
$ qemu-system-x86_64 \
  <b>-object</b> memory-backend-file,size=512M,mem-path=/hugetlbfs \
  [...]
</code></pre>
<pre><code data-trim data-noescape class="lang-bash">
$ qemu-system-x86_64 <b>-machine</b> pc,<b>accel=kvm</b>
</code></pre>
<pre><code data-trim data-noescape class="lang-bash">
$ qemu-system-x86_64 <b>-cpu Nehalem,+vmx,-nx,pmu=on</b>
</code></pre>
<pre><code data-trim data-noescape class="lang-c">
qemu_irq qemu_allocate_irq(...)
{
    irq = IRQ(object_new(TYPE_IRQ));
    <i>[...]</i>
}
</code></pre>
<pre><code data-trim data-noescape class="lang-c">
void memory_region_init(...)
{
    object_initialize(mr, sizeof(*mr), TYPE_MEMORY_REGION);
    <i>[...]</i>
}
</code></pre>

Note: QOM is used in lots of places. We already talked about
qdev, which is all built on top of QOM. Besides qdev, QOM is used
to handle backend objects, machine-type configuration,
accelerator configuration, and CPU configuration. QOM is also
used for some internal data structures like MemoryRegions and
IRQs. Probably there are other cases that I simply forgot or that
I'm not aware of, as lots of things in QEMU are built around QOM.



# Mixing Abstractions

Note: now that we have seen those interfaces individually, let's
what it happens when we try to use them together.

* TODO: Example: `query-command-line-option`


## Example: `-numa` option

(QemuOpts + QAPI)

<pre><code data-trim data-noescape class="lang-bash">
$ qemu-system-x86_64 <b class="strong">-numa node,cpus=0-1,mem=2G</b> \
                     <b class="strong">-numa node,2-3,mem=2G</b>
</code></pre>

Note: the first example is `-numa` command-line option. It is a
case where we mix QemuOpts and QAPI together.


### `-numa` QemuOptsList

<pre><code data-trim data-noescape class="lang-c">
QemuOptsList qemu_numa_opts = {
    .name = "numa",
    .implied_opt_name = "type",
    .head = QTAILQ_HEAD_INITIALIZER(qemu_numa_opts.head),
    <b class="strong">.desc = { { 0 } }</b>
};
</code></pre>

Note: This is how the `-numa` option is defined in the code. Note
the empty **.desc** field, where the list of accepted options
would be defined.


### `-numa` QAPI schema

<pre><code data-trim data-noescape class="lang-python">
{ 'union': 'NumaOptions',
  'data': {
    'node': 'NumaNodeOptions' } }

{ 'struct': 'NumaNodeOptions',
  'data': { '*nodeid': 'uint16',
            '*cpus':   ['uint16'],
            '*mem':    'size',
            '*memdev': 'str' } }
</code></pre>

Note: Instead of declaring them on QemuOpts, the `-numa` options
are all declared in the QAPI schema.


### `-numa` glue

<pre><code data-trim data-noescape class="lang-c">
static int parse_numa(void *opaque, QemuOpts *opts, Error **errp)
{
    NumaOptions *object = NULL;
    Visitor *v = opts_visitor_new(opts);
    visit_type_NumaOptions(v, NULL, &amp;object, &amp;err);
    /* [...] */
}
</code></pre>

Note: And this is the glue that makes that happen. When hadling a
`-numa` option, we use the OptsVisitor helper to translate the
QemuOpts data to a NumaOptions QAPI struct.


## Summary: `-numa`

* QAPI-based implementation
* QemuOpts-based interface
* All options documented in QAPI schema
* No duplication of QAPI schema info in the C code
* Glue code made possible by `OptsVisitor`
* Similar method used for:<br>`-net`, `-netdev`, `-acpitable`, `-machine`

Note: `-numa` is an example where fortunately things work as they
should. The options are all specified in the QAPI schema with no
code duplication. The OptsVisitor helper makes that possible.
Other command-line options use a similar method: `-net`,
`-netdev`, `-acpitable`, `-machine`.


## Example `object-add`<br>QMP command

(QAPI + QOM)

<pre><code data-trim data-noescape class="lang-c">
⇒ { "execute": "object-add",
     "arguments": { "qom-type": "rng-random", "id": "rng1",
                    "props": { "filename": "/dev/hwrng" } } }
⇐ { "return": {} }
</code></pre>

Note: the second example is mixing QOM and QAPI. Let's take a
look at the `object-add` QMP command. It creates a QOM object,
and can take different properties depending on the type of object
being created.


### `object-add`: QOM properties

<pre><code data-trim data-noescape class="lang-c">
static void rng_random_init(Object *obj)
{
    RngRandom *s = RNG_RANDOM(obj);
    <b>object_property_add_str</b>(obj, "filename",
                            rng_random_get_filename,
                            rng_random_set_filename,
                            NULL);
    /* [...] */
}
</code></pre>

Note: This is how the properties accepted by a type are defined:
they are registered as QOM properties by the corresponding QOM
class.


### `object-add` QAPI schema

<pre><code data-trim data-noescape class="lang-c">
{ 'command': 'object-add',
  'data': {'qom-type': 'str',
           'id': 'str',
           <b>'*props': 'any'</b> } }
</code></pre>

Note: This is how the QAPI schema for `object-add` looks like.
Note that the **props** parameter data type is **any**. It means
the actual options accepted by each QOM type are not declared in
the QAPI schema.


### Summary: `object-add`

* QOM-based implementation
* QAPI-based interface
* QAPI schema is incomplete
* Similar method used for: `device_add`

Note: So, in the case of `object-add`, the QAPI schema can't
reflect the data that depends on QOM information, so the
information in the QAPI schema is not complete. We have a similar
problem in the `device_add` QMP command.


## Example: `-cpu` option

(command-line + qdev/QOM)

<pre><code data-trim data-noescape class="lang-bash">
$ qemu-system-x86_64 <b>-cpu Nehalem,+vmx,-nx,pmu=on</b>
</code></pre>

Note: The next example is the `-cpu` option. It uses QOM
internally, but has its own method to parse the command-line.


### `-cpu`: QOM properties

<pre><code data-trim data-noescape class="lang-c">
void x86_cpu_register_bit_prop(X86CPU *cpu,
                               const char *prop_name,
                               uint32_t *field, int bitnr)
{
    <b>object_property_add</b>(OBJECT(cpu), prop_name, "bool",
                        x86_cpu_get_bit_prop,
                        x86_cpu_set_bit_prop,
                        x86_cpu_release_bit_prop, fp,
                        &amp;error_abort);
}
/* <i>[...]</i> */
static Property x86_cpu_properties[] = {
    <b>DEFINE_PROP_BOOL</b>("pmu", X86CPU, enable_pmu, false),
    /* <i>[...]</i> */
};
</code></pre>

Note: This is a sample of how the options accepted by `-cpu` are
specified. Each architecture registers their own QOM properties.
In the case of x86, as the number of features is very large, they
are registered dynamically based on a few internal tables.


### `-cpu`: glue code

<pre><code data-trim data-noescape class="lang-c">
static void x86_cpu_parse_featurestr(const char *typename,
                                     char *features,
                                     Error **errp)
{
    for (featurestr = strtok(features, ",");
         featurestr; featurestr = strtok(NULL, ",")) {
        /* [...] */
        prop->driver = typename;
        prop->property = g_strdup(name);
        prop->value = g_strdup(val);
        prop->errp = &amp;error_fatal;
        <b>qdev_prop_register_global(prop);</b>
    }
}
</code></pre>

Note: this is the glue between command-line parsing and qdev that
makes everything happen. The command-line parsing code registers
qdev global properties, which are a mechanism to set a property
value for every device of a given type.


### Summary: `-cpu`

* qdev/QOM-based implementation
* command-line interface
* Glue based on qdev's `-global` properties
* Not described on QAPI schema
* Still not ported to QemuOpts

Note:

For `-cpu`, we don't even have a QAPI schema for the option.
Information required to know which command-line options are
supported are available only using qdev-related commands.

`-cpu` has an additional problem: it doesn't use QemuOpts for
parsing the command-line options yet. But this should be fixed
soon.


## Example:<br>`query-cpu-model-expansion`

(QAPI + QOM)

<pre><code data-trim data-noescape class="lang-js">
⇒ { "execute": "query-cpu-model-expansion",
     "arguments": { "type": "static",
                    "model": { "name": "Nehalem" } } }
⇐ {"return": { "model": {"name": "base",
                          "props": { "cmov": true, "ia64": false,
                                     "aes": false, "mmx": true,
                                     "rdpid": false,
                                     "arat": false,
                                     <i>[...]</i> } } } }
</code></pre>

Note: Let's take a look at another example related to CPUs. This
is the `query-cpu-model-expansion` QMP command, that allows
management software to see what's really inside a CPU model name.


### `q-c-m-expansion`: QAPI schema

<pre><code data-trim data-noescape class="lang-js">
{ 'command': 'query-cpu-model-expansion',
  'data': { 'type': 'CpuModelExpansionType',
            'model': 'CpuModelInfo' },
  'returns': 'CpuModelExpansionInfo' }

{ 'struct': 'CpuModelExpansionInfo',
  'data': { 'model': 'CpuModelInfo' } }

{ 'struct': 'CpuModelInfo',
  'data': { 'name': 'str',
            <b>'*props': 'any'</b> } }
</code></pre>

Note: this is the QAPI schema for query-cpu-model-expansion. Note
the **props** attribute that is set to **any**. The command
documentation specifies that it returns a dictionary where each
key is a QOM property, but the schema doesn't tell us what's the
set of QOM properties that can be returned.


### Summary: `q-c-m-expansion`

* qdev/QOM-based implementation
* QAPI-based interface
* QAPI schema is incomplete
* Arch-specific glue code (currently)

Note: In the case of `query-cpu-model-expansion`, the QAPI schema
also doesn't have all information about supported attributes,
because each attribute is a QOM property. Another issue is that
the glue code that maps CPU models to QOM properties is
archictecture-specific, today.


## Summary: QOM &amp; the QAPI schema

* QOM classes and properties are registered at run time (`class_init` &amp; `instance_init` methods)
* QAPI schema is a static file
* QOM class-specific info doesn't appear on QAPI schema

Note: One pattern we see when using QOM-based implementations
with QAPI is that QOM interface information is not available in
the QAPI schema. This happens because QOM interfaces are
registered at runtime, and the QAPI schema is a static file in
QEMU source code.


# Conclusion

Note:
* TODO: mention existing work in progress


## Please ask

Some practices are not well-documented.

When in doubt, ask developers &amp; qemu-devel.

Note: Lots of practices in QEMU are not documented anywhere. This
talk is also an attempt to write down some of the things that
were just learned in practice. So, if you have any questions
about how things work, don't hesitate to ask in the qemu-devel
mailing list.


## Questions?


# Thank You

This slide deck:<br>
https://habkost.net/talks/fosdem-2017/

Incomplete guide to QEMU APIs:<br>
https://goo.gl/c8SzD7


# Appendix


## Interface documentation

* QAPI schema: <b>comprehensive</b>
* QemuOpts: <b>brief</b>
* QOM types and properties: <b>almost none</b>

Note: quality of documentation of external interfaces vary a lot,
especially depending on the method used to build that interface.
Interfaces modelled using the QAPI schema have very detailed
documentation. QemuOpts-based interfaces often have brief
documentation embedded in the code. QOM types and properties, on
the other hand, are rarely documented, which is a problem today.


## Data types

<table style="font-size: smaller">
  <tr>
    <th>Type</th>
    <th>int</th>
    <th>float</th>
    <th>bool</th>
    <th>string</th>
    <th>enum</th>
    <th>list</th>
    <th>dict</th>
  </tr>
  <tr>
    <td>QemuOpts</td>
    <td>✔\*</td>
    <td></td>
    <td>✔</td>
    <td>✔</td>
    <td></td>
    <td><span style="color: #bbb;">✔\*\*</span></td>
    <td></td>
  </tr>
  <tr>
    <td>qdev</td>
    <td>✔\*</td>
    <td></td>
    <td>✔</td>
    <td>✔</td>
    <td>✔</td>
    <td></td>
    <td></td>
  </tr>
  <tr>
    <td>QAPI</td>
    <td>✔</td>
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
    <td>✔</td>
    <td><span style="color: #bbb;">✔\*\*</span></td>
    <td><span style="color: #bbb;">✔\*\*</span></td>
  </tr>
  <tr>
    <td colspan="8" style="font-size: 75%; padding-top: 1em;">
    \* Limited support<br>
    \*\* Very limited support
    </td>
  </tr>
</table>

Note: Most of the APIs I have talked about involve some type of
data representation. This is a summary of data types supported by
them. QAPI have the most powerful type system. QemuOpts and qdev
are mor limited. QOM is almost as powerful as QAPI, but not
exactly the same. In theory it can support all QAPI types, but in
practice it is more limited. QemuOpts has only one list type:
integer lists.


## Abstractions equivalency

<style type="text/css">
table.abstractions { font-size: smaller; }
table.abstractions th {font-weight:bold;vertical-align:top}
.static { background-color: #999; color: #111; }
.gray { background-color: #778; color: #111; }
.runtime { color: #eee; background-color: #336; }
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
    <td class="gray">option default</td>
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


### QOM: internal vs. external

* Unclear:
  * What should be user-visible
  * What should be a stable interface
* *Types* can be hidden from the user (`no_user`)
* *Properties* can't be hidden
  * Today's (undocumented) convention: <b>"x-"</b> prefix

Note: Currently one problem with QOM is that it is used both to
implement internal and external interfaces, and sometimes there's
no clear line dividing them. QOM types can be easily hidden from
the user, but properties that are intended for external usage are
still visible to the outside, meaning they can be read through
QMP and configured through QMP or the command-line. This makes it
risky to change property semantics, because we don't know if some
other software is relying on it. We have been trying to use a
naming convention to indicate which properties are experimental
or intended for internal usage only. That's a "x-" prefix on
property names. But this convention is not used very widely yet.


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


## Not Covered

* Migration system (VMState, savevm handlers)
* Main loop
* Char devices
* Block layer
* Coroutines
* Many more

Note: These are some APIs and abstractions that I didn't cover in
this talk, just for reference.


## Interfaces <i>vs</i> internal abstractions

* QMP commands: built on top of **QAPI**
* (Many) Command-line options: handled using **QemuOpts**
* `-device`/`device_add`: built on top of **qdev**
* `-object`/`object-add`: built on top of **QOM**
* `-cpu`: built on top of **qdev**

Note: some of the external interfaces exposed by QEMU are built
on top of existing abstractions. This is supposed to be OK,
because some APIs are specialized for some tasks. But this
becomes a problem when we want to translate stuff between those
abstractions.


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


## Issue: Introspection &amp; data availability


## Translation issues:
* Incompatible data-types
* Data unavailable at the right time


## Issue: overlap and duplication

* APIs providing similar features
* Some code is not shared


## Duplication example:
* Parsing code

Note:
* TODO: image for parsing code


## Overlap example:

Data representation: QemuOpts vs QOM vs QAPI

* OK when translation is possible
* Interface design dilemmas when translation is not possible
* Affects design of external interfaces

Note:
* TODO: count how many

* TODO: examples

Example: Commplex interface based on QOM properties can't benefit
from QAPI schema.


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

Note: TODO: Table: information availability 


## Data items

* qdev type list
* QOM properties
* QemuOpts sections
* QAPI schema
* machine-type list
* machine-type defaults
* machine-type devices

Note:
* TODO: Image/table: showing data flow on top of the table above.
* Why is this a problem: introspection.


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
