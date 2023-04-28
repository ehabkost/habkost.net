# KVM and CPU identification in x86

- [KVM and CPU identification in x86](#kvm-and-cpu-identification-in-x86)
  - [The basics: CPUID and MSR](#the-basics-cpuid-and-msr)
    - [`CPUID` instruction](#cpuid-instruction)
      - [Official documentation for CPUID fields](#official-documentation-for-cpuid-fields)
      - [Visualizing CPUID data](#visualizing-cpuid-data)
    - [MSRs (Model Specific Registers)](#msrs-model-specific-registers)
      - [Visualizing MSR data](#visualizing-msr-data)
      - [Official documentation for MSRs](#official-documentation-for-msrs)
    - [Userspace visibility of CPU features](#userspace-visibility-of-cpu-features)
      - [`CPUID` instruction](#cpuid-instruction-1)
      - [MSRs](#msrs)
      - [`/proc/cpuinfo`](#proccpuinfo)
    - [Virtualization and CPU features](#virtualization-and-cpu-features)
  - [(WIP) How the Linux kernel keeps track of CPU features](#wip-how-the-linux-kernel-keeps-track-of-cpu-features)
  - [(WIP) How libvirt/QEMU/KVM stack controls CPU features](#wip-how-libvirtqemukvm-stack-controls-cpu-features)
- [Drafts/notes](#draftsnotes)
      - [Meaning of CPUID fields](#meaning-of-cpuid-fields)
  - [TODO](#todo)


## The basics: CPUID and MSR

There are two main CPU identification and feature enumeration mechanisms in x86
that are covered by this guide: the `CPUID` instruction and *Model
Specific Registers* (MSRs).

### `CPUID` instruction

The `CPUID` instruction has a very simple interface. Quoting the [Intel
documentation][intel-sdm]:

> CPUID returns processor identification and feature information in the EAX,
EBX, ECX, and EDX registers.1 The instruction’s output is dependent on the
contents of the EAX register upon execution (in some cases, ECX as well). [...]

It can be seen as a function that takes two inputs (EAX and ECX) and returns
four outputs (EAX, EBX, ECX and EDX).

With very few exceptions, information returned by `CPUID` is constant for a
given processor, and don't change at runtime[^changing-cpuid].

[^changing-cpuid]: CPU virtualization capabilities let hypervisor software
change `CPUID` data seen by guest software inside a virtual machine at runtime.
However, this can make guest software crash or misbehave, and on most
circumstances that would be considered a hypervisor bug.

The `CPUID` output values corresponding to a specific EAX input value are often
called *CPUID leaves*.  Values that depend on both EAX and ECX input are often
called *sub-leaves*. When this guide refers to a specific register or specific
bits of a specific register, they will be refered as *CPUID fields*.

This guide follows a the same notation as the Intel manuals to refer to CPUID
fields.  As an example, `CPUID.01H:EDX.SSE[bit 25]` represents:
* `01H`: the input value for the EAX register
* `EDX`: the output register
* `SSE`: the field or feature name
* `bit 25`: the bit number in the output register


#### Official documentation for CPUID fields

The official documentation for CPUID fields can be found at:

* For Intel CPUs: "CPUID—CPU Identification" section in Volume 2 of the [Intel SDM][intel-sdm]
* For AMD CPUs: [AMD CPUID Specification][amd-cpuid]
* For KVM virtual CPUs: [KVM CPUID documentation][kvm-cpuid-doc] (more details on this later)


#### Visualizing CPUID data

The [x86info tool][x86info-tool] can be used to visualize CPUID data from your
processor.  Here's an example:

```
$ x86info -a
x86info v1.31pre  Dave Jones 2001-2011
Feedback to <davej@redhat.com>.

Found 16 identical CPUs
Extended Family: 0 Extended Model: 8 Family: 6 Model: 141 Stepping: 1
Type: 0 (Original OEM)
CPU Model (x86info's best guess): Unknown model. 
Processor name string (BIOS programmed): 11th Gen Intel(R) Core(TM) i7-11850H @ 2.50GHz

eax in: 0x00000000, eax = 0000001b ebx = 756e6547 ecx = 6c65746e edx = 49656e69
eax in: 0x00000001, eax = 000806d1 ebx = 00100800 ecx = 7ffafbff edx = bfebfbff
eax in: 0x00000002, eax = 00feff01 ebx = 000000f0 ecx = 00000000 edx = 00000000
eax in: 0x00000003, eax = 00000000 ebx = 00000000 ecx = 00000000 edx = 00000000
eax in: 0x00000004, eax = 1c004121 ebx = 02c0003f ecx = 0000003f edx = 00000000
eax in: 0x00000005, eax = 00000040 ebx = 00000040 ecx = 00000003 edx = 11121020
eax in: 0x00000006, eax = 0017eff7 ebx = 00000002 ecx = 00000009 edx = 00000000
eax in: 0x00000007, eax = 00000000 ebx = 00000000 ecx = 00000000 edx = 00000000
eax in: 0x00000008, eax = 00000000 ebx = 00000000 ecx = 00000000 edx = 00000000
eax in: 0x00000009, eax = 00000000 ebx = 00000000 ecx = 00000000 edx = 00000000
eax in: 0x0000000a, eax = 08300805 ebx = 00000000 ecx = 0000000f edx = 00008604
eax in: 0x0000000b, eax = 00000000 ebx = 00000000 ecx = 0000000f edx = 00000000
eax in: 0x0000000c, eax = 00000000 ebx = 00000000 ecx = 00000000 edx = 00000000
eax in: 0x0000000d, eax = 000002e7 ebx = 00000a88 ecx = 00000a88 edx = 00000000
eax in: 0x0000000e, eax = 00000000 ebx = 00000000 ecx = 00000000 edx = 00000000
eax in: 0x0000000f, eax = 00000000 ebx = 00000000 ecx = 00000000 edx = 00000000
eax in: 0x00000010, eax = 00000000 ebx = 00000004 ecx = 00000000 edx = 00000000
eax in: 0x00000011, eax = 00000000 ebx = 00000000 ecx = 00000000 edx = 00000000
eax in: 0x00000012, eax = 00000000 ebx = 00000000 ecx = 00000000 edx = 00000000
eax in: 0x00000013, eax = 00000000 ebx = 00000000 ecx = 00000000 edx = 00000000
eax in: 0x00000014, eax = 00000001 ebx = 0000004f ecx = 00000007 edx = 00000000
eax in: 0x00000015, eax = 00000002 ebx = 00000082 ecx = 0249f000 edx = 00000000
eax in: 0x00000016, eax = 000009c4 ebx = 000012c0 ecx = 00000064 edx = 00000000
eax in: 0x00000017, eax = 00000000 ebx = 00000000 ecx = 00000000 edx = 00000000
eax in: 0x00000018, eax = 00000008 ebx = 00000000 ecx = 00000000 edx = 00000000
eax in: 0x00000019, eax = 00000007 ebx = 00000014 ecx = 00000003 edx = 00000000
eax in: 0x0000001a, eax = 00000000 ebx = 00000000 ecx = 00000000 edx = 00000000
eax in: 0x0000001b, eax = 00000000 ebx = 00000000 ecx = 00000000 edx = 00000000

eax in: 0x80000000, eax = 80000008 ebx = 00000000 ecx = 00000000 edx = 00000000
eax in: 0x80000001, eax = 00000000 ebx = 00000000 ecx = 00000121 edx = 2c100800
eax in: 0x80000002, eax = 68743131 ebx = 6e654720 ecx = 746e4920 edx = 52286c65
eax in: 0x80000003, eax = 6f432029 ebx = 54286572 ecx = 6920294d edx = 31312d37
eax in: 0x80000004, eax = 48303538 ebx = 32204020 ecx = 4730352e edx = 00007a48
eax in: 0x80000005, eax = 00000000 ebx = 00000000 ecx = 00000000 edx = 00000000
eax in: 0x80000006, eax = 00000000 ebx = 00000000 ecx = 01007040 edx = 00000000
eax in: 0x80000007, eax = 00000000 ebx = 00000000 ecx = 00000000 edx = 00000100
eax in: 0x80000008, eax = 00003027 ebx = 00000000 ecx = 00000000 edx = 00000000

Cache info
TLB info
 64 byte prefetching.
Found unknown cache descriptors: fe ff 
Feature flags:
 fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflsh ds acpi mmx fxsr sse sse2 ss ht tm pbe sse3 pclmuldq dtes64 monitor ds-cpl vmx smx est tm2 ssse3 [1:ecx:11] fma cx16 xTPR pdcm pcid sse4_1 sse4_2 x2apic movbe popcnt tsc-deadline aes xsave osxsave avx [1:ecx:29] [1:ecx:30]
Extended feature flags:
 SYSCALL xd pdpe1gb rdtscp em64t lahf_lm [80000001:ecx:5] [80000001:ecx:8] dts ida arat pln ecmd ptm [6:eax:7] [6:eax:8] [6:eax:9] [6:eax:10] [6:eax:11] [6:eax:13] [6:eax:14] [6:eax:15] [6:eax:16] [6:eax:17] [6:eax:18] [6:eax:20] nonstop_tsc
Long NOPs supported: yes

Address sizes : 39 bits physical, 48 bits virtual
2.50GHz processor (estimate).

Total processor threads: 16
This system has 1 eight-core processor with hyper-threading (2 threads per core) running at an estimated 2.50GHz
```

### MSRs (Model Specific Registers)

x86 CPUs have a set of registers called *model-specific registers* (MSRs), which
can be read using the `RDMSR` instruction.  Despite their name, some of these
registers are now considered *architectural*, meaning they are part of the x86
architecture and are not specific to any particular CPU model.  In the Intel
documentation, those architectural MSRs are named with a `IA32_` prefix.

**Note:** the `RDMSR` instruction is privileged and can't be executed from userspace.

The list of MSRs is huge (the chapter for MSRs in the [Intel SDM][intel-sdm] is
more than 500 pages long), but we'll focus only on a few registers that contain
fields describing CPU capabilities, such as:

* `IA32_ARCH_CAPABILITIES`
* `IA32_CORE_CAPABILITIES`
* `IA32_PERF_CAPABILITIES`
* VMX capability registers such as:
  * `IA32_VMX_TRUE_PINBASED_CTLS`
  * `IA32_VMX_TRUE_PROCBASED_CTLS`
  * `IA32_VMX_TRUE_EXIT_CTLS`
  * `IA32_VMX_TRUE_ENTRY_CTLS`


#### Visualizing MSR data

There are tools that will show the contents of *some* MSRs in a human-readable
format. For example:

* `x86info -m` will show some MSRs
* The [vmxcap script](https://github.com/qemu/qemu/blob/master/scripts/kvm/vmxcap) from QEMU will show the contents of VMX capability MSRs

The `rdmsr` tool from the [msr-tools] project can be used to read arbirary MSRs,
but it is a low level tool that requires looking up the MSR numbers in the CPU
documentation.

#### Official documentation for MSRs

The official documentation for MSRs can be found at:

* For Intel CPUs: Volume 4 of the [Intel SDM][intel-sdm]
* For AMD CPUs: Appendix A: MSR Cross-Reference of the [AMD64 Architecture Programmer’s Manual][amd-manual]


### Userspace visibility of CPU features

Userspace doesn't have the same visibility as the kernel into CPU features.
Different mechanisms are available to userspace to get information about CPU
features:

#### `CPUID` instruction

Userspace is able to execute the `CPUID` instruction, with no special privileges
required, and the same data is available to userspace as to the
kernel[^cpuid-fault].  This is why tools like `cpuid` and `x86info` don't
require any special privileges to work.

[^cpuid-fault]: CPUID faulting and [ARCH_SET_CPUID](https://github.com/torvalds/linux/commit/e9ea1e7f53b852147cbd568b0568c7ad97ec21a3) makes this a bit more complicated, but I'm ignoring that for now.

#### MSRs

The `RDMSR` instruction only works at privilege level 0, so userspace can't
execute it directly.  However, software like `msr-tools` and `x86info` can read
MSRs using the special devices at `/dev/cpu/*/msr` if they have the right
permissions.


#### `/proc/cpuinfo`

The `/proc/cpuinfo` file is probably the most popular and obvious way to get
most information about CPU features in Linux.  Example output:

```
processor	: 0
vendor_id	: GenuineIntel
cpu family	: 6
model		: 141
model name	: 11th Gen Intel(R) Core(TM) i7-11850H @ 2.50GHz
stepping	: 1
microcode	: 0x42
cpu MHz		: 1198.237
cache size	: 24576 KB
physical id	: 0
siblings	: 16
core id		: 0
cpu cores	: 8
apicid		: 0
initial apicid	: 0
fpu		: yes
fpu_exception	: yes
cpuid level	: 27
wp		: yes
flags		: fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush dts acpi mmx fxsr sse sse2 ss ht tm pbe syscall nx pdpe1gb rdtscp lm constant_tsc art arch_perfmon pebs bts rep_good nopl xtopology nonstop_tsc cpuid aperfmperf tsc_known_freq pni pclmulqdq dtes64 monitor ds_cpl vmx smx est tm2 ssse3 sdbg fma cx16 xtpr pdcm pcid sse4_1 sse4_2 x2apic movbe popcnt tsc_deadline_timer aes xsave avx f16c rdrand lahf_lm abm 3dnowprefetch cpuid_fault epb cat_l2 invpcid_single cdp_l2 ssbd ibrs ibpb stibp ibrs_enhanced tpr_shadow vnmi flexpriority ept vpid ept_ad fsgsbase tsc_adjust bmi1 avx2 smep bmi2 erms invpcid rdt_a avx512f avx512dq rdseed adx smap avx512ifma clflushopt clwb intel_pt avx512cd sha_ni avx512bw avx512vl xsaveopt xsavec xgetbv1 xsaves split_lock_detect dtherm ida arat pln pts hwp hwp_notify hwp_act_window hwp_epp hwp_pkg_req avx512vbmi umip pku ospke avx512_vbmi2 gfni vaes vpclmulqdq avx512_vnni avx512_bitalg tme avx512_vpopcntdq rdpid movdiri movdir64b fsrm avx512_vp2intersect md_clear ibt flush_l1d arch_capabilities
vmx flags	: vnmi preemption_timer posted_intr invvpid ept_x_only ept_ad ept_1gb flexpriority apicv tsc_offset vtpr mtf vapic ept vpid unrestricted_guest vapic_reg vid ple shadow_vmcs pml ept_mode_based_exec tsc_scaling
bugs		: spectre_v1 spectre_v2 spec_store_bypass swapgs eibrs_pbrsb
bogomips	: 4992.00
clflush size	: 64
cache_alignment	: 64
address sizes	: 39 bits physical, 48 bits virtual
power management:

```

The most interesting `/proc/cpuinfo` fields for this guide are `flags`, `vmx
flags` and `bugs`.  We'll discuss how `/proc/cpuinfo` works in more detail
later.


### Virtualization and CPU features

When running a virtual machine in x86 using KVM, the following things are
different from regular bare metal `CPUID` and `RDMSR`:

* Every `CPUID` and `RDMSR` instruction can[^vmexits-rdmsr] be intercepted and handled by KVM
* The output of the `CPUID` and `RDMSR` instructions can be 100% controlled by KVM

KVM can lie as much as it wants when handling `CPUID` and `RDMSR` instructions.
The challenge here is telling *lies that won't break guest software*.  In general,
it's okay to report a feature as unavailable when it's actually available—guest
software will simply not try to use the feature.  On the other hand, if the
hypervisor report a feature as available and the feature doesn't work as
expected, guest software will break.

[^vmexits-rdmsr]: This doesn't mean every single `RDMSR` instruction will cause
    a *VM Exit*, it just means KVM is able to fully control what happens when a
    `RDMSR` instruction is executed.  See section 15.11 "MSR Intercepts" on
    Volume 2 of the [AMD manual][amd-manual] and section 25.3 "Changes to
    Instruction Behavior in VMX Non-Root Operation" on Volume 3 of the [Intel
    SDM][intel-sdm] for low-level details.


## (WIP) How the Linux kernel keeps track of CPU features

```mermaid
flowchart TB
        subgraph CPU
            cpuid(CPUID instruction)
            msrs[MSRs]
        end
        cpuid --> cpu_caps
        msrs --> cpu_caps
        subgraph Kernel
            direction LR
            kernel_cmdline["Kernel command line"]
            cpu_caps
            cpuinfo["/proc/cpuinfo"]
            kernel_cmdline --> cpu_caps
            cpu_caps --> cpuinfo
        end
        subgraph Userspace
            cpuid --> user_proc
            cpuinfo --> user_proc
            user_proc["User process"]
        end
```

## (WIP) How libvirt/QEMU/KVM stack controls CPU features

```mermaid
flowchart TB
    subgraph Host
        direction TB
        subgraph CPU
            cpuid(CPUID instruction)
            msrs[MSRs]
        end
        cpuid --> cpu_caps
        msrs --> cpu_caps
        subgraph Host Kernel
            direction LR
            kernel_cmdline["Kernel command line"]
            cpu_caps
            cpuinfo["/proc/cpuinfo"]
            kernel_cmdline --> cpu_caps
            cpu_caps --> cpuinfo
            subgraph KVM
                KVM_GET_SUPPORTED_CPUID
                KVM_GET_MSRS
                KVM_SET_CPUID2
                KVM_SET_MSRS
                ? --> KVM_GET_MSRS
            end
            cpu_caps --> KVM_GET_SUPPORTED_CPUID
        end
        subgraph Host Userspace
            direction LR

            qemu["QEMU"]
            cpuid --> qemu
            KVM_GET_SUPPORTED_CPUID --> qemu
            KVM_GET_MSRS --> qemu
            qemu --> KVM_SET_CPUID2
            qemu --> KVM_SET_MSRS
        end
        subgraph VM
            subgraph VCPU
                subgraph vcpu[struct vcpu]
                    direction TB

                    vcpu_cpuid_entries[cpuid_entries]
                    msr_fields["(multiple fields)"]
                end
                vm_cpuid("CPUID instruction")
                vm_rdmsr("RDMSR instruction")
                KVM_SET_CPUID2 --> vcpu_cpuid_entries
                KVM_SET_MSRS --> msr_fields
                vcpu_cpuid_entries --> vm_cpuid
                msr_fields --> vm_rdmsr
            end
        end
    end
```




[kvm-cpuid-doc]: https://www.kernel.org/doc/Documentation/virtual/kvm/cpuid.txt
[intel-sdm]: https://www.intel.com/content/www/us/en/developer/articles/technical/intel-sdm.html "Intel 64 and IA-32 Architectures
Software Developer’s Manual"
[amd-cpuid]: https://www.amd.com/system/files/TechDocs/25481.pdf "AMD CPUID Specification"
[amd-manual]: https://www.amd.com/system/files/TechDocs/40332.pdf "AMD64 Architecture Programmer’s Manual, Volumes 1–5"
[x86info-tool]: https://github.com/kernelslacker/x86info
[msr-tools]: https://github.com/intel/msr-tools

# Drafts/notes


#### Meaning of CPUID fields

The *meaning* of CPUID fields depend on the EAX and ECX input values.  The most
relevant CPUID fields for this guide are:

* `CPUID.01H.EDX`
* `CPUID.01H.ECX`
* `CPUID.80000001H.EDX`
* `CPUID.80000001H.ECX`

The fields above contain a set of flags where `1` indicates the CPU supports a
specific feature.  Note that most CPUID fields are *not* just a set of boolean
flags, but in this guide we're focusing on those boolean flags.

## TODO

Items to include:

* Linux kernel cpu_cap data structures
* `/proc/cpuinfo` contents
* KVM CPUID tables
* QEMU CPUID func
* QEMU feature_words table
* QEMU CPU model table
* QEMU command-line and QMP
* libvirt cpu_map.xml
* libvirt domain XML
