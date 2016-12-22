---
layout: post
---

* controller-pci-root:
  * hotpluggable: true
  * accepts: pci-device pci-bridge pci-expander-bus
  * minSlot: 1
  * maxSlot: VIR_PCI_ADDRESS_SLOT_LAST
  * type: none
* controller-pcie-root:
  # slots 1 - 31, no hotplug, PCIe endpoint device or
  # pcie-root-port only, unless the address was specified in
  # user config *and* the particular device being attached also
  # allows it.
  #
  * accepts: pcie-device pcie-root-port dmi-to-pci-bridge pcie-expander-bus
  * minSlot: 1
  * maxSlot: VIR_PCI_ADDRESS_SLOT_LAST
  * type: none
* controller-pci-bridge:
  * hotpluggable: true
  * accepts: pci-device pci-bridge
  * minSlot: 1
  * maxSlot: VIR_PCI_ADDRESS_SLOT_LAST
  * type: pci-bridge
* controller-pci-expander-bus:
  * hotpluggable: true
  * accepts: pci-device pci-bridge
  * minSlot: 0
  * maxSlot: VIR_PCI_ADDRESS_SLOT_LAST
  * type: pci-expander-bus
* controller-dmi-to-pci-bridge:
  # slots 0 - 31, standard PCI slots,
  # but *not* hot-pluggable */
  * accepts: pci-device pci-bridge
  * minSlot: 0
  * maxSlot: VIR_PCI_ADDRESS_SLOT_LAST
  * type: dmi-to-pci-bridge
* controller-pcie-root-port:
  # provides one slot which is pcie, can be used by endpoint
  # devices and pcie-switch-upstream-ports, and is hotpluggable
  #
  * hotpluggable: true
  * accepts: pcie-device pcie-switch-upstream-port
  * minSlot: 0
  * maxSlot: 0
  * type: pcie-root-port
* controller-pcie-switch-downstream-port:
  # provides one slot which is pcie, can be used by endpoint
  # devices and pcie-switch-upstream-ports, and is hotpluggable
  #
  * hotpluggable: true
  * accepts: pcie-device pcie-switch-upstream-port
  * minSlot: 0
  * maxSlot: 0
  * type: pcie-switch-downstream-port
* controller-pcie-switch-upstream-port:
  # 32 slots, can only accept pcie-switch-downstrean-ports,
  # no hotplug
  #
  * accepts: pcie-switch-downstream-port
  * minSlot: 0
  * maxSlot: VIR_PCI_ADDRESS_SLOT_LAST
  * type: pcie-switch-upstream-port
* controller-pcie-expander-bus:
  # 32 slots, no hotplug, only accepts pcie-root-port or
  # dmi-to-pci-bridge
  #
  * accepts: pcie-root-port dmi-to-pci-bridge
  * minSlot: 0
  * maxSlot: VIR_PCI_ADDRESS_SLOT_LAST
  * type: pcie-expander-bus
