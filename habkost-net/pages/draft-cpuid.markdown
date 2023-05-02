---
layout: page
permalink: /docs/kvm-cpuid-guide.html
title: KVM and CPU identification in x86
---
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
- [How the Linux kernel keeps track of CPU features](#how-the-linux-kernel-keeps-track-of-cpu-features)
- [How KVM controls CPU features](#how-kvm-controls-cpu-features)
  - [Differences to bare metal](#differences-to-bare-metal)
  - [Overview](#overview)
  - [The meaning of "supported" in `KVM_GET_SUPPORTED_CPUID`](#the-meaning-of-supported-in-kvm_get_supported_cpuid)
- [How QEMU controls CPU features](#how-qemu-controls-cpu-features)
  - [Machine type compat properties](#machine-type-compat-properties)
  - [Feature filtering](#feature-filtering)
  - [What can make a feature be filtered out?](#what-can-make-a-feature-be-filtered-out)
  - [Live migration](#live-migration)
  - [Visualizing QEMU's view of CPU flags](#visualizing-qemus-view-of-cpu-flags)
- [How libvirt controls CPU features](#how-libvirt-controls-cpu-features)
  - [libvirt APIs related to CPU model/features](#libvirt-apis-related-to-cpu-modelfeatures)
  - [Caveats](#caveats)
    - [libvirt API is not QEMU-specific nor KVM-specific](#libvirt-api-is-not-qemu-specific-nor-kvm-specific)
    - [libvirt's own CPU model definitions](#libvirts-own-cpu-model-definitions)
    - [libvirt's own feature name definitios](#libvirts-own-feature-name-definitios)
    - [Features hidden behind a CPU model](#features-hidden-behind-a-cpu-model)
    - [Enabling `-cpu ...,enforce`](#enabling--cpu-enforce)
    - [Backwards compatibility and non-optimal defaults](#backwards-compatibility-and-non-optimal-defaults)
- [Drafts/notes](#draftsnotes)
- [Types of features](#types-of-features)
  - [Boolean CPUID flags](#boolean-cpuid-flags)


# The basics: CPUID and MSR

*If you are already familiar with the CPUID instruction and x86 MSRs, you can
skip this section.*

There are two main CPU identification and feature enumeration mechanisms in x86
that are covered by this guide: the `CPUID` instruction and *Model
Specific Registers* (MSRs).

## `CPUID` instruction

The `CPUID` instruction has a very simple interface. It can be seen as a
function that takes two 32-bit inputs (EAX and ECX) and returns four outputs
(EAX, EBX, ECX and EDX). Quoting the [Intel documentation][intel-sdm]:

> CPUID returns processor identification and feature information in the EAX,
EBX, ECX, and EDX registers.1 The instruction’s output is dependent on the
contents of the EAX register upon execution (in some cases, ECX as well). [...]


With very few exceptions, information returned by `CPUID` is constant for a
given processor, and don't change at runtime[^changing-cpuid].

[^changing-cpuid]: CPU virtualization capabilities let hypervisor software
change `CPUID` data seen by guest software inside a virtual machine at runtime.
However, this can make guest software crash or misbehave, and on most
circumstances that would be considered a hypervisor bug.

The output values corresponding to a specific EAX input value are often called
*CPUID leaves*.  Values that depend on both EAX and ECX input are often called
*sub-leaves*. When this guide refers to a specific register or specific bits of
a specific register, they will be refered as *CPUID fields*.


### Official documentation for CPUID fields

The official documentation for CPUID fields can be found at:

* For Intel CPUs: "CPUID—CPU Identification" section in Volume 2 of the [Intel SDM][intel-sdm]
* For AMD CPUs: [AMD CPUID Specification][amd-cpuid]
* For KVM virtual CPUs: [KVM CPUID documentation][kvm-cpuid-doc] (more details on this later)


### Visualizing CPUID data

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

## MSRs (Model Specific Registers)

x86 CPUs have a set of registers called *model-specific registers* (MSRs), which
can be read using the `RDMSR` instruction.  Despite their name, some of these
registers are considered *architectural*, meaning they are part of the x86
architecture and are not specific to a particular CPU model.  In the Intel
documentation, architectural MSRs are named with a `IA32_` prefix.

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


### Visualizing MSR data

There are tools that will show the contents of *some* MSRs in a human-readable
format. For example:

* `x86info -m` will show some MSRs
* The [vmxcap script](https://github.com/qemu/qemu/blob/master/scripts/kvm/vmxcap) from QEMU will show the contents of VMX capability MSRs

The `rdmsr` tool from the [msr-tools] project can be used to read arbirary MSRs,
but it is a low level tool that requires looking up the MSR numbers in the CPU
documentation.

### Official documentation for MSRs

The official documentation for MSRs can be found at:

* For Intel CPUs: Volume 4 of the [Intel SDM][intel-sdm]
* For AMD CPUs: Appendix A: MSR Cross-Reference of the [AMD64 Architecture Programmer’s Manual][amd-manual]


## Userspace visibility of CPU features

Different mechanisms are available to userspace to get information about CPU
features:

### `CPUID` instruction

Userspace is able to execute the `CPUID` instruction, with no special privileges
required, and the same data is available to userspace as to the
kernel[^cpuid-fault].  This is why tools like `cpuid` and `x86info` don't
require any special privileges to work.

[^cpuid-fault]: CPUID faulting and [ARCH_SET_CPUID](https://github.com/torvalds/linux/commit/e9ea1e7f53b852147cbd568b0568c7ad97ec21a3) makes this a bit more complicated, but I'm ignoring that for now.

### MSRs

The `RDMSR` instruction only works at privilege level 0, so userspace can't
execute it directly.  However, software like `msr-tools` and `x86info` can read
MSRs using the special devices at `/dev/cpu/*/msr` if they have the right
permissions.


### `/proc/cpuinfo`

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


# How the Linux kernel keeps track of CPU features

```mermaid
flowchart TB
        subgraph CPU
            direction LR
            cpuid(CPUID instruction)
            msrs[MSRs]
        end
        cpuid --> cpuinfo_x86
        msrs --> cpuinfo_x86
        subgraph Kernel
            direction LR
            kernel_cmdline["Kernel command line"]
            cpuinfo_x86[struct cpuinfo_x86]
            cpuinfo["/proc/cpuinfo"]
            kernel_cmdline --> cpuinfo_x86
            cpuinfo_x86 --> cpuinfo
        end
```

Most kernel code won't look at the output of CPUID instructions directly.  Normally they will use the macros provided by [arch/x86/include/asm/cpufeature.h](https://github.com/torvalds/linux/blob/master/arch/x86/include/asm/cpufeature.h), like `cpu_has()`.  

Details are documented at [Documentation/x86/cpuinfo.rst](https://docs.kernel.org/x86/cpuinfo.html), but some things to keep in mind:
* The flags on /proc/cpuinfo come directly from cpuinfo_x86
* The names on /proc/cpuinfo don't necessarily match the names in Intel or AMD documentation
* Not every CPUID flag is represented in cpuinfo_x86 and /proc/cpuinfo
* Not every flag in cpuinfo_x86 and /proc/cpuinfo correspond to a single flag in CPUID or a MSR
* Flags can be disabled in cpuinfo_x86 even if hardware supports them

The full list of cpuinfo_x86 flags is defined at
[arch/x86/include/asm/cpufeatures.h](https://github.com/torvalds/linux/blob/master/arch/x86/include/asm/cpufeatures.h).
Note that the file is split in different sections: some sections correspond to
specific CPUID leaves, while some sections contain flags coming from multiple
sources.

# How KVM controls CPU features

## Differences to bare metal

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


## Overview

The following diagram shows the *data flow* between relevant KVM ioctls
related to CPU feature configuration:

```mermaid
flowchart TB
    subgraph Host
        direction LR

        subgraph CPU
            cpuid(CPUID instruction)
            msrs[MSRs]
        end
        cpuid --> cpuinfo_x86
        msrs --> cpuinfo_x86

        subgraph Host Userspace
            direction LR
            qemu["QEMU"]
        end

        KVM_GET_SUPPORTED_CPUID --> qemu
        KVM_GET_MSRS --> qemu
        KVM_GET_MSR_FEATURE_INDEX_LIST --> qemu
        qemu --> KVM_SET_CPUID2
        qemu --> KVM_SET_MSRS

        subgraph Host Kernel
            direction TB
            cpuinfo_x86[struct cpuinfo_x86]
            subgraph KVM
                kvm_set_cpu_caps("kvm_set_cpu_caps()")
                kvm_get_msr_feature("kvm_get_msr_feature()")
                kvm_init_msr_list("kvm_init_msr_list()")

                msr_based_features["msr_based_features[]"]

                KVM_GET_SUPPORTED_CPUID("ioctl(KVM_GET_SUPPORTED_CPUID)")
                KVM_GET_MSR_FEATURE_INDEX_LIST("ioctl(KVM_GET_MSR_FEATURE_INDEX_LIST)")
                KVM_GET_MSRS("ioctl(KVM_GET_MSRS)")
                KVM_SET_CPUID2("ioctl(KVM_SET_CPUID2)")
                KVM_SET_MSRS("ioctl(KVM_SET_MSRS)")

                subgraph vcpu[struct vcpu]
                    direction TB

                    vcpu_cpuid_entries[cpuid_entries]
                    msr_fields["(multiple fields)"]
                end

                kvm_set_cpu_caps --> KVM_GET_SUPPORTED_CPUID
                kvm_get_msr_feature --> kvm_init_msr_list
                kvm_get_msr_feature --> KVM_GET_MSRS
                msrs --> kvm_init_msr_list
                kvm_init_msr_list --> msr_based_features
                msr_based_features --> KVM_GET_MSR_FEATURE_INDEX_LIST

            end
            cpuinfo_x86 --> kvm_set_cpu_caps
            cpuid --> kvm_set_cpu_caps
            cpuid_handler(CPUID VM Exit handler)
            rdmsr_handler(RDMSR VM Exit handler)
            vcpu_cpuid_entries --> cpuid_handler
            msr_fields --> rdmsr_handler
        end
    end

    cpuid_handler --> vm_cpuid
    rdmsr_handler --> vm_rdmsr

    subgraph Virtual Machine Guest
            vm_cpuid("CPUID instruction")
            vm_rdmsr("RDMSR instruction")
            KVM_SET_CPUID2 --> vcpu_cpuid_entries
            KVM_SET_MSRS --> msr_fields
    end

```

The diagram is pretty complex, but the most important ideas are:

* **QEMU is in control**: QEMU is 100% in control of which
  CPU features are reported to the guest, using the `KVM_SET_CPUID2` and
  `KVM_SET_MSRS` ioctls.
* **Data exposed to QEMU is already filtered**: the CPUID and MSR data exposed
  through the `KVM_GET_SUPPORTED_CPUID`, `KVM_GET_MSR_FEATURE_INDEX_LIST` and
  `KVM_GET_MSRS` ioctls is the result of multiple layers of filtering done by
  the kernel.

The documentation for the KVM API (including the ioctls mentioned above) can be
found at <https://docs.kernel.org/virt/kvm/api.html>.


## The meaning of "supported" in `KVM_GET_SUPPORTED_CPUID`

Most of the features returned by `KVM_GET_SUPPORTED_CPUID` are features
supported by *both* host hardware and by KVM.  However, it's possible for some
features to be enabled efficiently even if the host CPU doesn't support them.
In those cases, the feature will still be returned by `KVM_GET_SUPPORTED_CPUID`.
The most common example of this is the `x2apic` feature, that is entirely
implemented by the KVM APIC emulation code, and doesn't require host hardware
support.


# How QEMU controls CPU features

The following diagram shows the *data flow* between multiple stages of the
initialization of VCPU features by QEMU:

```mermaid
flowchart TB
    subgraph Host Kernel
        direction LR
        subgraph KVM
            KVM_GET_SUPPORTED_CPUID("ioctl(KVM_GET_SUPPORTED_CPUID)")
            KVM_GET_MSR_FEATURE_INDEX_LIST("ioctl(KVM_GET_MSR_FEATURE_INDEX_LIST)")
            KVM_GET_MSRS("ioctl(KVM_GET_MSRS)")
            KVM_SET_CPUID2("ioctl(KVM_SET_CPUID2)")
            KVM_SET_MSRS("ioctl(KVM_SET_MSRS)")

        end
    end
    subgraph Host Userspace
        direction LR

        subgraph qemu["QEMU"]
            subgraph qemucmdline["command line"]
                machine_opt["-machine ..."]
                global_opt["-global ..."]
                cpu_opt["-cpu ..."]
            end
            subgraph Hardcoded data
                direction TB
                cpu_model_table["CPU model table"]
                cpu_flag_names["CPU flag name table"]
                qemu_machine_type_table["Machine type table"]
            end

            host_cpu_model["host cpu model"]

            cpu_model["CPU model"]
            subgraph qemucpu["VCPU object"]
                direction TB
                feature_words["feature_words[]"]
                filtered_features["filtered_features[]"]
            end
            subgraph machinetype["machine type"]
                machine_compat_props["compat_props"]
            end
            cpu_global_props["cpu global properties"]

            parse_cpu_opt("Parse -cpu option")
            parse_globals("Parse -global option")

            pick_cpu_model("Lookup CPU model")
            pick_machine_type("Lookup machine type")

            x86_cpu_get_supported_feature_word("x86_cpu_get_supported_feature_word()")

            subgraph VCPU initialization sequence
                direction TB
                init_cpu("Initialize VCPU")
                apply_globals("Apply global properties")
                filter_features("Filter features")
                kvm_arch_init_vcpu("kvm_arch_init_vcpu()")
                init_cpu -.-> apply_globals -.-> filter_features -.-> kvm_arch_init_vcpu
            end

            cpu_opt --> parse_cpu_opt
            global_opt --> parse_globals

            x86_cpu_get_supported_feature_word --> host_cpu_model
            host_cpu_model --> pick_cpu_model

            cpu_model_table --> pick_cpu_model
            parse_cpu_opt --> pick_cpu_model
            parse_cpu_opt --> cpu_global_props
            parse_globals --> cpu_global_props
            pick_cpu_model --> cpu_model

            cpu_model --> init_cpu

            cpu_flag_names --> apply_globals
            cpu_global_props --> apply_globals

            init_cpu --> feature_words
            apply_globals --> feature_words

            x86_cpu_get_supported_feature_word --> filter_features
            filter_features --> feature_words
            filter_features --> filtered_features
            feature_words --> kvm_arch_init_vcpu

            machine_opt --> pick_machine_type
            qemu_machine_type_table --> pick_machine_type
            pick_machine_type --> machinetype
            machine_compat_props --> init_cpu

        end
        KVM_GET_SUPPORTED_CPUID --> x86_cpu_get_supported_feature_word
        KVM_GET_MSR_FEATURE_INDEX_LIST --> x86_cpu_get_supported_feature_word
        KVM_GET_MSRS --> x86_cpu_get_supported_feature_word
        kvm_arch_init_vcpu --> KVM_SET_CPUID2
        kvm_arch_init_vcpu --> KVM_SET_MSRS
    end
```

Highlights of the process:
* **Feature names**: QEMU has its own feature name table. It normally matches
  the feature names used by the Linux kernel, but there are exceptions.
* **Machine compat_props**: There's a subtle interaction between CPU models and
  machine types. Details below.
* **Feature filtering**: QEMU filters out features not supported by the host.
  Details below.
* **Live migration**: the initialization process is **the same** when live
  migrating a VM from another host.  This has some consequences for live
  migration safety.  Details below.

## Machine type compat properties

Historically, QEMU used machine-type-provided compatibility properties to
introduce changes in CPU models while keeping compatibility with older QEMU
versions.  This meant the machine type chosen for the VM (controlled using the
`-machine` option) would also affect CPU features visible to guests.  This
breaks some assumptions encoded in the libvirt CPU model APIs, which don't take
the machine type as input on CPU model introspection operations.

Since QEMU 4.1 (Aug 2019), a new **version** of a CPU model is introduced when
CPU model changes need to be introduced.  This ensures the selected machine type
won't affect the CPU features seen by guests.


## Feature filtering

QEMU feature filtering is subtle.  It's one of the areas where the default
behavior of QEMU is not the safest or most appropriate, but it never changed
upstream due to fears of breaking compatibility with existing software.

The default behavior of QEMU when a feature is requested but not supported by
the host is to just **disable the feature, print a warning, and keep running**.
This means the same QEMU command line can produce different results on different
hosts. This has consequences for live migration safety (see next section).

The safer behavior (refusing to run the VM if a feature is missing) can be
enabled by using the `-cpu ...,enforce` command line option.

## What can make a feature be filtered out?

Some of the reasons a feature might be filtered out by QEMU:

* Feature reported by KVM as unsupported.  This can happen if:
  * Feature is not supported by the host CPU;
  * Feature is supported by the host CPU, but:
    * not supported by KVM yet;
    * supported by KVM, but:
      * was disabled by a build-time option;
      * was disabled automatically due to a known issue;
      * was disabled in the kernel command line.
* Feature reported by KVM as supported, but;
  * QEMU doesn't know about it yet;
  * QEMU knows about the feature yet, but:
    * QEMU doesn't support live migration with the feature yet.


## Live migration

QEMU **does not send CPUID data in the live migration stream** when live
migrating.  QEMU generates the CPUID data again on the migration destination.
This has consequences for live migration safety, because any QEMU changes that
affects the resulting CPUID data can make CPUID flags change during live
migration, which may have unexpected consequences for guests.

QEMU normally don't change guest-visible CPUID data accross QEMU versions, but
the exceptions are:

* **Feature filtering** (see above): when not using the `-cpu ...,enforce`
  option, the same QEMU command line may result in different CPUID flags.
* **-cpu host**: the `host` CPU model in QEMU will use KVM-provided host CPUID
  data, which may change when live migrating to a different host[^host-migration].
* **QEMU bugs**: if not careful about live migration compatibility it's easy to
  introduce changes that affect CPUID flags in QEMU.  Bugs like these can go
  undetected for a long time because there's no CPUID data validation during
  live migration.

[^host-migration]: In theory, live migration using `-cpu host` can work if
    strict conditions are met.  In practice, it's very easy to break and it's
    discouraged.

## Visualizing QEMU's view of CPU flags

TODO: describe a simple way to query for info from the `max` CPU model using QMP.


# How libvirt controls CPU features

## libvirt APIs related to CPU model/features

The main reference for configuring CPU model for a VM in libvirt is at:
https://libvirt.org/formatdomain.html#cpu-model-and-topology

For querying information about CPU models and features, there are multiple
mechanisms available:

* [virConnectBaselineHypervisorCPU](https://libvirt.org/html/libvirt-libvirt-host.html#virConnectBaselineHypervisorCPU) for querying hypervisor CPU model and features.
* [virConnectBaselineCPU](https://libvirt.org/html/libvirt-libvirt-host.html#virConnectBaselineCPU), which is probably not what you are looking for.
* The [VIR_DOMAIN_XML_UPDATE_CPU](https://libvirt.org/html/libvirt-libvirt-domain.html#VIR_DOMAIN_XML_UPDATE_CPU) flag at [virDomainGetXMLDesc](https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainGetXMLDesc) can be used to check which CPU model and features were actually enabled for a VM.


## Caveats


### libvirt API is not QEMU-specific nor KVM-specific

libvirt tries very hard to be a generic API for virtualization, which means the
semantics of CPU models and features often won't match QEMU's behavior
exactly.


### libvirt's own CPU model definitions

libvirt has its own CPU model definitions, which are normally stored in
`/usr/share/libvirt/cpu_map`.  libvirt's documentation states:

> The list of available CPU models and their definition can be found in
> directory cpu_map, installed in libvirt's data directory. If a hypervisor is
> not able to use the exact CPU model, libvirt automatically falls back to a
> closest model supported by the hypervisor while maintaining the list of CPU
> features.

The documentation isn't clear on what happens if libvirt and QEMU disagree on
the exact definition of a CPU model.


### libvirt's own feature name definitios

The feature name supported by libvirt are also stored in the `cpu_map`
directory.  The names used by libvirt and QEMU normally match, but this isn't
always guaranteed.  Also, some features may be not present in libvirt's
`cpu_map` list and can't be controlled by libvirt.

The lack of a feature name in libvirt's `cpu_map` makes it difficult for libvirt
to report when those features are filtered out by QEMU.


### Features hidden behind a CPU model

Many of the libvirt APIs that return CPU model information won't return feature
names explicitly if they are already considered part of the CPU model.  This is
normally not a problem when libvirt and QEMU agree on the CPU model definition,
but it can make the data ambiguous or incomplete when they disagree.

See https://libvirt.org/html/libvirt-libvirt-host.html#VIR_CONNECT_BASELINE_CPU_EXPAND_FEATURES at https://libvirt.org/html/libvirt-libvirt-host.html#virConnectBaselineCPU for possible mechanisms to work around this.


### Enabling `-cpu ...,enforce`

There's no obvious way to enable the `-cpu ...,enforce` QEMU option using libvirt.

In theory, it should be possible to enable equivalent behavior in libvirt by
using the `match` or `check` attributes in [libvirt's `cpu`
element](https://libvirt.org/formatdomain.html#cpu-model-and-topology), but the
documentation is not entirely clear.


### Backwards compatibility and non-optimal defaults

Most of the non-obvious behavior of libvirt can be explained by backwards
compatibility guarantees.  Sometimes it's not possible to change libvirt's
existing behavior without breaking existing code, and new behavior needs to be
explicitly enabled by new attributes or flags.



[kvm-cpuid-doc]: https://docs.kernel.org/virt/kvm/x86/cpuid.html
[kvm-api-doc]: https://docs.kernel.org/virt/kvm/api.html
[intel-sdm]: https://www.intel.com/content/www/us/en/developer/articles/technical/intel-sdm.html "Intel 64 and IA-32 Architectures
Software Developer’s Manual"
[amd-cpuid]: https://www.amd.com/system/files/TechDocs/25481.pdf "AMD CPUID Specification"
[amd-manual]: https://www.amd.com/system/files/TechDocs/40332.pdf "AMD64 Architecture Programmer’s Manual, Volumes 1–5"
[x86info-tool]: https://github.com/kernelslacker/x86info
[msr-tools]: https://github.com/intel/msr-tools

# Drafts/notes


# Types of features

## Boolean CPUID flags

The *meaning* of CPUID fields depend on the EAX and ECX input values.  The most
relevant CPUID fields for this guide are:

* `CPUID.01H.EDX`
* `CPUID.01H.ECX`
* `CPUID.80000001H.EDX`
* `CPUID.80000001H.ECX`

The fields above contain a set of flags where `1` indicates the CPU supports a
specific feature.  Note that most CPUID fields are *not* just a set of boolean
flags, but in this guide we're focusing on those boolean flags.
