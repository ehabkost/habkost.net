---
layout: post
title:  QEMU, KVM, machine-types and Guest ABI
categories: 
slug: qemu-guest-abi
---

## What is Guest ABI?

In general terms, *Guest ABI* can be defined as all interfaces
between guest software and the virtual hardware presented by a
virtual machine.  This includes the CPU instruction set, device
registers and their I/O addresses, expected behavior of virtual
hardware.

Often when talking about Guest ABI, we're talking about **stable
Guest ABI**, which was
[originally defined](https://www.linux-kvm.org/page/StableABI#Stable_Guest_ABI)
as allowing *"guest virtual machines to be presented with the
same ABI across QEMU upgrades"*.

I would extend this definition from "across QEMU upgrades" to
"across host *software and hardware upgrades*".  This means
presenting a stable guest ABI to guest software even if all the
host software and hardware is changed.

## Why keep a Stable Guest ABI?

Short answer: changing guest ABI can confuse or break guest
software.  Windows guests, for example, may require license
reactivation if there are unexpected changes on virtual hardware.

For live migration, a stable guest ABI is an absolute
requirement: as the guest operating system is still running, all
the interfaces currently being used by the guest must stay
working after migration.

## The command-line interface

QEMU implements stable guest ABI by providing **versioned machine
types**.  Not all QEMU target architectures provided versioned
machine-types that guarantee stable APIs.  As of today (August
2018), the machine-type families that provide versioned
machine-types are:

* The `virt-*` machines in `qemu-system-arm`
* The `pseries-*` machines in `qemu-system-ppc64`
* The `s390-ccw-virtio-*` machines in `qemu-system-s390x`
* The `pc-*` machines in `qemu-system-i386` and `qemu-system-x86_64`

In general, the guarantee you can expect from QEMU is:

> If using a **versioned machine-type** and the same QEMU device
> options, all QEMU versions will present the same Guest ABI to
> guests.

Note that in practice this isn't that simple.  See the next
sections below for the tricky details.


## What is considered part of the Guest ABI?

Below is an incomplete list of what is considered part of the
Guest ABI and must not change when using the same machine-type
and device options:

* **Virtual CPU model and features:** on x86, this means all data returned to the guest by the `CPUID` instruction.
* **I/O and memory addresses of virtual hardware:** this means all I/O and memory addresses see by the guest
* **Virtual device addresses and topology:** this means the list of buses and devices visible to the guest, their addresses and how they are wired together.
* **Virtual NUMA topology:**
* **Identification data of virtual hardware:** this means SMBIOS tables or other hardware identifiers visible to the guest.

<!-- ### Runtime state of virtual hardware -->
<!--  -->
<!-- Runtime state is **not** part of the Guest ABI.  However, -->
<!-- changing hardware state in a way that is not expected by the -->
<!-- guest might be still a bug in the hardware emulation. -->


## Factors that aren't supposed to affect Guest ABI

Things that are not directly exposed to the guest OS are normally
not part of the guest ABI.  Examples:

* Backend options like `-object`, `-chardev`, and `-blockdev`
* Binding of guest RAM to host NUMA nodes
* Pinning of VCPU and other threads to host CPUs
* Kernel and KVM module version
* Model and features of the physical host CPU
* Any host hardware
* Internal QOM tree topology in QEMU


## Exceptions and corner cases

* CPU vendor
* -cpu host
* host-phys-bits=on
* vhost-user?
* hardware passthrough
* ACPI and other BIOS tables
* BIOS images
* Hotplugged hardware


## Implementation details

## TODO

* Talk about migration-safe CPU models


## References

https://fedoraproject.org/wiki/Features/KVM_Stable_Guest_ABI
https://fedoraproject.org/wiki/KVM_Stable_Guest_ABI_Design_Notes
https://fedoraproject.org/wiki/Features/KVM_Stable_PCI_Addresses


# Thanks

Thanks to Kashyap Chamarthy, who reviewed early drafts of this
document.
