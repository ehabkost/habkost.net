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


# Contents

* Context: QEMU features and interfaces
* Overview of some internal QEMU APIs
* Interaction between different abstractions

Note: These are the contents of this talk. I will first explain a
little bit of what QEMU does, then present of the internal APIs
QEMU has. Then I will talk about how they work and don't work
together.


## Incomplete

* Limited time
* Limited knowledge

Note: Keep in mind that this talk is incomplete: we do not cover
every single internal QEMU API. That's because we don't have much
time and I don't have knowldge about all those APIs.


## *Not* included:

* The <i>right</i> way to do something
* Solutions to issues

Note:

If I were talking only to QEMU developers, I would probably be
suggesting how to fix some issues and change how things work. We
often see this sort of talk on KVM Forum, for example.

Here I will **try** to not present solutions or suggest how to
fix things. This is an introduction only. It may generate some
interesting discussion later, though.


# Context

Note: Let's see some of the context: what QEMU does and needs to
do.


> "QEMU is a generic and open source machine emulator and virtualizer."
> 
> &mdash; http://qemu.org/

Note:

This is how QEMU is described at its web site. I won't try to
explain all about it, but the summary is: QEMU can be used as an
emulator, or for running KVM or Xen virtual machines while
emulating some of the hardware.


## Interfaces

* Command-line
* Config files
* Machine Monitor (QMP)
* Human Monitor (HMP)

Note:

QEMU has multiple interface to interact with the outside world.
The main ones are: the command-line and the monitor. There are
two monitor modes: one for humans, and one for machines called
QMP.

* TODO: Image: QEMU command-line
* TODO: Image: QEMU monitor
* TODO: Image: QMP

QMP is the machine-friendly monitor protocol. It is based
on JSON.

QMP is used for most runtime communication between QEMU and
management software. The same code is also reused for
communication between QEMU and QEMU Guest Agent inside VMs.



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
configuration and device state, and backend configuration.


## Internal APIs

Note: let's talk about the internal APIs that let QEMU do its job.


## API: QemuOpts (2009)

* Parsing and storage of command-line options
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


## QemuOpts example
<pre><code data-trim data-noescape class="lang-bash">
$ qemu-system-x86_64 <b>-memory 2G,maxmem=4G</b>
</code></pre>

<pre><code data-trim data-noescape class="lang-c">
static QemuOptsList qemu_mem_opts = {
    .name = "memory",
    .implied_opt_name = "size",
    .head = QTAILQ_HEAD_INITIALIZER(qemu_mem_opts.head),
    .merge_lists = true,
    .desc = {
        { .name = "size",   .type = QEMU_OPT_SIZE, },
        { .name = "slots",  .type = QEMU_OPT_NUMBER, },
        { .name = "maxmem", .type = QEMU_OPT_SIZE, },
        { /* end of list */ }
    },
};
</code></pre>


## QemuOpts usage

* <strike>Most</strike> Many command-line options
* Config file support (`-readconfig`, `-writeconfig`)
* Internal storage of config options

Note: QemuOpts is used to parse many (or most, depending of how
you count) of the command-line options, as a storage system for
config options, and to read and write VM configuration to config
files. Note that as config options can be exported, QEMU tries to
store all configuration options inside QemuOpts so it can be
exported later.


## API: qdev (2009)

* Bus/device tree
* Single API to create, configure and plug devices
* Property system, introspection
* Reference counting

Note:

qdev is the bus and device tree system hierarchy system. It
allows QEMU to provide a unified interface to create, configure
and plug devices. It means having generic internal and external
APIs to handle devices. It provides a property system that allow
introspection of all device configuration.

* TODO: Image: -device command-line
* TODO: Image: info qtree


## qdev Example

<pre><code data-trim data-noescape class="lang-bash">
$ qemu-system-x86_64 <b>-device e1000,mac=12:34:56:78:9a:bc</b>
</code></pre>

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

Note:

QAPI is a system for defining QEMU external interfaces. It uses a
JSON-like language for defining data structures and interfaces
(like QMP commands). It provides a visitor API for implementing
data input, output and conversion, and generates visitor code,
code for serialization, and for dispatching QMP commands.


## QAPI usage

* All QMP commands
* Some command-line options

Note: QAPI is successfully used to define and dispatch all QMP
commands, and to define and parse a few command-line options.
Every single data structure and QMP command has very detailed
documentation. It is a great system.

TODO: check list of internal/non-QMP interfaces or types.


## QAPI Example: `chardev-add`

<pre><code data-trim data-noescape class="lang-json">
-> { "execute" : "chardev-add",
     "arguments" : {
         "id" : "bar",
         "backend" : { "type" : "file",
                       "data" : { "out" : "/tmp/bar.log" } } } }
<- { "return": {} }
</code></pre>


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
* *Accelerator* configuration (TCG, KVM, Xen)<br>(`-machine accel=...`)
* machine-type system (`-machine`)
* CPU configuration system<br>(`-cpu`, `query-cpu-*`)
* Direct manipulation through QMP<br>(`qom-list`, `qom-get`, `qom-set`)
* Some internal data structures (MemoryRegions, IRQs)

Note: QOM is also quite successful. Most of the existing qdev
code is just a wrapper around QOM abstractions. QOM used to build
a generic system for creating and configuring backend objects. We
also ported multiple subsystems to be built on top of QOM,
including the machine-type system, accelerator configuration, and
the CPU configuration system. QOM is also used for some internal
data structures like MemoryRegions and IRQs.


<!-- -->
<!-- ## QOM tree manipulation-->
<!-- -->
<!-- * QOM device/object tree can be manipulated through QMP-->
<!-- * Not very popular in practice-->
<!-- -->
<!-- Note: The QOM object tree is exposed to the outside through QMP-->
<!-- commands. In theory this could be used to provide generic-->
<!-- interfaces to configure and manipulate devices and objects-->
<!-- without introducing new specialized QMP commands. But in practice-->
<!-- we normally add new commands and structs in the QAPI schema-->
<!-- instead of just letting new features be implemented through pure-->
<!-- QOM manipulation. There are multiple reasons for that, and I hope-->
<!-- some of them will be clear in the rest of this talk.-->
<!-- -->

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


## Interface documentation

* QAPI schema: <b>comprehensive</b>
* QemuOpts: <b>brief</b>
* QOM types and properties: <b>almost none</b>




# Mixing abstractions


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
    <td>✔\*</td>
    <td></td>
    <td>✔</td>
    <td>✔</td>
    <td><span style="color: #bbb;">✔\*</span></td>
    <td></td>
  </tr>
  <tr>
    <td>qdev</td>
    <td>✔\*</td>
    <td></td>
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
  </tr>
  <tr>
    <td>QOM</td>
    <td>✔</td>
    <td>✔</td>
    <td>✔</td>
    <td>✔</td>
    <td><span style="color: #bbb;">✔\*\*</span></td>
    <td><span style="color: #bbb;">✔\*\*</span></td>
  </tr>
</table>

<div style="margin-top: 1em; text-align: left; font-size: 75%;">
\* Limited support<br>
\*\* Very limited support
</div>

Note: Most of the APIs I have talked about involve some type of
data representation. This is a summary of data types supported by
some of those APIs. QAPI have the most powerful type systems.
QemuOpts and qdev are mor limited. QOM is almost as powerful as
QAPI, but not exactly the same. In theory it can support all QAPI
types, but in practice it is more limited. QemuOpts has only one
list type: integer lists.


<!-- ## Interfaces <i>vs</i> internal abstractions -->
<!--  -->
<!-- * QMP commands: built on top of **QAPI** -->
<!-- * (Many) Command-line options: handled using **QemuOpts** -->
<!-- * `-device`/`device_add`: built on top of **qdev** -->
<!-- * `-object`/`object-add`: built on top of **QOM** -->
<!-- * `-cpu`: built on top of **qdev** -->
<!--  -->
<!-- Note: some of the external interfaces exposed by QEMU are built -->
<!-- on top of existing abstractions. This is supposed to be OK, -->
<!-- because some APIs are specialized for some tasks. But this -->
<!-- becomes a problem when we want to translate stuff between those -->
<!-- abstractions. -->
<!--  -->
<!--  -->
## Example: `-numa` option

<pre><code data-trim data-noescape class="lang-bash">
$ qemu-system-x86_64 <b class="strong">-numa node,cpus=0-1,mem=2G</b> \
                     <b class="strong">-numa node,2-3,mem=2G</b>
</code></pre>


### `-numa` QemuOptsList

<pre><code data-trim data-noescape class="lang-c">
QemuOptsList qemu_numa_opts = {
    .name = "numa",
    .implied_opt_name = "type",
    .head = QTAILQ_HEAD_INITIALIZER(qemu_numa_opts.head),
    <b class="strong">.desc = { { 0 } }</b>
};
</code></pre>


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


### `-numa` glue

<pre><code data-trim data-noescape class="lang-c">
static int parse_numa(void *opaque, QemuOpts *opts, Error **errp)
{
    Visitor *v = opts_visitor_new(opts);
    visit_type_NumaOptions(v, NULL, &amp;object, &amp;err);
    /* [...] */
}
</code></pre>


## Summary: `-numa`

* All options documented in QAPI schema
* No duplication of QAPI schema info in the C code
* Glue code made possible by `OptsVisitor`
* Similar method used for:<br>`-net`, `-netdev`, `-acpitable`, `-machine`


## Example `object-add`<br>QMP command

<pre><code data-trim data-noescape class="lang-c">
-> { "execute": "object-add",
     "arguments": { "qom-type": "rng-random", "id": "rng1",
                    "props": { "filename": "/dev/hwrng" } } }
<- { "return": {} }
</code></pre>


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


### `object-add` QMP schema

<pre><code data-trim data-noescape class="lang-c">
{ 'command': 'object-add',
  'data': {'qom-type': 'str',
           'id': 'str',
           <b>'*props': 'any'</b> } }
</code></pre>


### Summary: `object-add`

* QOM-based interface
* QAPI schema is incomplete
* Similar method used for `device_add`


## Example: `-cpu` option

<pre><code data-trim data-noescape class="lang-bash">
$ qemu-system-x86_64 <b>-cpu Nehalem,+vmx,-nx</b>
</code></pre>


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
/* [...] */
static Property x86_cpu_properties[] = {
    <b>DEFINE_PROP_BOOL</b>("pmu", X86CPU, enable_pmu, false),
};
</code></pre>


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


### Summary: `-cpu`

* qdev/QOM-based
* Not described on QAPI schema
* Glue based on qdev's `-global` properties
* Still not ported to QemuOpts


## Example:<br>`query-cpu-model-expansion`

<pre><code data-trim data-noescape class="lang-js">
-> { "execute": "query-cpu-model-expansion",
     "arguments": { "type": "static",
                    "model": { "name": "Nehalem" } } }
<- {"return": { "model": {"name": "base",
                          "props": { "cmov": true, "ia64": false,
                                     "aes": false, "mmx": true,
                                     "rdpid": false,
                                     "arat": false,
                                     <i>[...]</i> } } } }
</code></pre>


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


### Summary: `q-c-m-expansion`

* qdev/QOM-based
* QAPI schema is incomplete
* Arch-specific glue code (currently)


<!-- ## TODO: Example: `query-command-line-option` -->

## Summary: QOM/qdev and the QAPI schema

* QOM interfaces are registered/defined at run time (`class_init` & `instance_init` methods)
* QAPI schema is a static file



# Conclusion


# Not Covered

* Migration system (VMState, savevm handlers)
* Main loop
* Char devices
* Block layer
* Coroutines

Note: Things not covered by this talk, but could be explored further.


## More

http://habkost.net/talks/fosdem-2017/



# Appendix


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



