KVM and CPU identification in x86
================================

Where CPUID information comes from / goes to?

* Output of CPUID instruction
* Linux kernel cpu_cap data structures
* `/proc/cpuinfo` contents
* KVM CPUID tables
* QEMU CPUID func
* QEMU feature_words table
* QEMU CPU model table
* QEMU command-line and QMP
* libvirt cpu_map.xml
* libvirt domain XML

See Also:
* Documentation/x86/cpuinfo.rst
