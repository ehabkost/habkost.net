# Building a Virtual CPU from the Ground Up
## KVM and the layers above it
Eduardo Habkost &lt;ehabkost@redhat.com&gt;

Note:
TODO:
* Diagram multiple hosts
* Diagram live-migration + host features
* Glossário

Details to mention:
* Live-migration and guest ABI
* CPUID and live-migration
* CPU model updates (+ versioned CPU models)
* Defaults + libosinfo
* Backwards compatibility + inability to change defaults


## Contents

* Introduction (quick dive in)
* Emulating a virtual machine (slow ascent)

Note:
This is how I will present this talk.  First we we start from the 



# Introduction


## A virtual machine

<img src="virtual-machine.png" style="width: 75%; border: none;">


## The Layers

<img src="onion.jpg" width="40%">
<!-- credit: https://www.flickr.com/photos/theilr/4947839133 -->

Note:
Let's start peeling the onion and remove all the layers.
This section can also be called "how to peel an onion"


## First layer: the user interface

<table class="layers">
<tr class="current"><td>management app</td></tr>
<tr class="hidden"><td>libvirt</td></tr>
<tr class="hidden"><td>QEMU</td></tr>
<tr class="hidden"><td>KVM (kernel)</td></tr>
<tr class="hidden"><td>Hardware (CPU)</td></tr>
</table>

Note:
I will show you one example of how it looks from the outside.  I
will use the virt-manager tool as an example because that's what
I know how to use.  There are other tools out there for desktops
(like Boxes), and there are lots of other solutions for the
server side, but the basics would be still the same.


### Creating a VM
<img src="new-vm-1.png" width="100%">

Note:
This is the user interface for creating a new VM on virt-manager.
First it asks you how you want to install it.  I chose to use an
ISO image.


### Install location
<img src="new-vm-2.png" width="100%">

Note:
Then it asks you where the install media is.


### CPU & RAM
<img src="new-vm-3.png" width="100%">

Note:
Then it asks you how you want to allocate resources for the
virtual machine, including CPU and RAM...


### Storage
<img src="new-vm-4.png" width="100%">

Note:
and disk storage for the VM.


### A Running Virtual Machine
<img src="new-vm-running.png" width="125%">

Note:
Then your VM is up and running.  I used a Fedora ISO image so
it's running a live desktop with an option to install Fedora in
the hard disk.


<!-- ## Next layer:  -->
<!--   -->
<!-- <table class="layers">  -->
<!-- <tr><td>management app</td></tr>  -->
<!-- <tr class="current"><td>virtinst</td></tr>  -->
<!-- </table>  -->
<!--   -->
<!--   -->
<!-- ## virtinst interface  -->
<!--   -->
<!-- <pre><code>  -->
<!-- # virt-install                              \  -->
<!-- > --name fedora28                           \  -->
<!-- > --location ~ehabkost/Downloads/fedora.iso \  -->
<!-- > --vcpus 2                                 \  -->
<!-- > --ram 1024                                \  -->
<!-- > --disk format=qcow2,path=/var/lib/libvirt/images/fedora28.qcow2,size=8  -->
<!--   -->
<!-- </code></pre>  -->
<!--   -->
<!-- Note:  -->
<!--   -->
<!-- virtinst is a Python module used by virt-manager, and  -->
<!-- virt-install is a command-line interface that exposes the same  -->
<!-- functionality.  The command-line shown here is equivalent to the  -->
<!-- options I have chosen on virt-manager: it specifies the install  -->
<!-- media location, CPU, RAM and storage resources, and the VM will  -->
<!-- be created.  -->
<!--  -->
<!--  -->
## Next layer:

<table class="layers">
<tr><td>management app</td></tr>
<tr class="current"><td>libvirt</td></tr>
<tr class="hidden"><td>QEMU</td></tr>
<tr class="hidden"><td>KVM (kernel)</td></tr>
<tr class="hidden"><td>Hardware (CPU)</td></tr>
</table>


## libvirt interface (XML)

<pre style="font-size: 0.25em"><code data-trim class="xml">
<domain type="kvm">
  <name>fedora28</name>
  <uuid>34e74d0e-2de0-4c0d-b6f7-4ad1ac1262b7</uuid>
  <memory>1048576</memory>
  <currentMemory>1048576</currentMemory>
  <vcpu>2</vcpu>
  <os>
    <type arch="x86_64">hvm</type>
    <kernel>/var/lib/libvirt/boot/virtinst-vmlinuz.SqGhHd</kernel>
    <initrd>/var/lib/libvirt/boot/virtinst-initrd.img.Ix7vKA</initrd>
  </os>
  <features>
    <acpi/>
    <apic/>
    <vmport state="off"/>
  </features>
  <cpu mode="custom" match="exact">
    <model>Skylake-Client</model>
  </cpu>
  <clock offset="utc">
    <timer name="rtc" tickpolicy="catchup"/>
    <timer name="pit" tickpolicy="delay"/>
    <timer name="hpet" present="no"/>
  </clock>
  <on_reboot>destroy</on_reboot>
  <pm>
    <suspend-to-mem enabled="no"/>
    <suspend-to-disk enabled="no"/>
  </pm>
  <devices>
    <emulator>/usr/bin/qemu-kvm</emulator>
    <disk type="file" device="disk">
      <driver name="qemu" type="qcow2"/>
      <source file="/var/lib/libvirt/images/fedora28.qcow2"/>
      <target dev="vda" bus="virtio"/>
    </disk>
    <disk type="file" device="cdrom">
      <driver name="qemu" type="raw"/>
      <source file="/home/ehabkost/Downloads/Fedora-Workstation-Live-x86_64-28-1.1.iso"/>
      <target dev="hda" bus="ide"/>
      <readonly/>
    </disk>
    <controller type="usb" index="0" model="ich9-ehci1"/>
    <controller type="usb" index="0" model="ich9-uhci1">
      <master startport="0"/>
    </controller>
    <controller type="usb" index="0" model="ich9-uhci2">
      <master startport="2"/>
    </controller>
    <controller type="usb" index="0" model="ich9-uhci3">
      <master startport="4"/>
    </controller>
    <interface type="network">
      <source network="default"/>
      <mac address="52:54:00:22:19:06"/>
      <model type="virtio"/>
    </interface>
    <input type="tablet" bus="usb"/>
    <graphics type="spice" port="-1" tlsPort="-1" autoport="yes">
      <image compression="off"/>
    </graphics>
    <console type="pty"/>
    <channel type="unix">
      <source mode="bind"/>
      <target type="virtio" name="org.qemu.guest_agent.0"/>
    </channel>
    <channel type="spicevmc">
      <target type="virtio" name="com.redhat.spice.0"/>
    </channel>
    <sound model="ich6"/>
    <video>
      <model type="qxl"/>
    </video>
    <redirdev bus="usb" type="spicevmc"/>
    <redirdev bus="usb" type="spicevmc"/>
    <rng model="virtio">
      <backend model="random">/dev/urandom</backend>
    </rng>
  </devices>
</domain>
<domain type="kvm">
  <name>fedora28</name>
  <uuid>34e74d0e-2de0-4c0d-b6f7-4ad1ac1262b7</uuid>
  <memory>1048576</memory>
  <currentMemory>1048576</currentMemory>
  <vcpu>2</vcpu>
  <os>
    <type arch="x86_64">hvm</type>
    <boot dev="hd"/>
  </os>
  <features>
    <acpi/>
    <apic/>
    <vmport state="off"/>
  </features>
  <cpu mode="custom" match="exact">
    <model>Skylake-Client</model>
  </cpu>
  <clock offset="utc">
    <timer name="rtc" tickpolicy="catchup"/>
    <timer name="pit" tickpolicy="delay"/>
    <timer name="hpet" present="no"/>
  </clock>
  <pm>
    <suspend-to-mem enabled="no"/>
    <suspend-to-disk enabled="no"/>
  </pm>
  <devices>
    <emulator>/usr/bin/qemu-kvm</emulator>
    <disk type="file" device="disk">
      <driver name="qemu" type="qcow2"/>
      <source file="/var/lib/libvirt/images/fedora28.qcow2"/>
      <target dev="vda" bus="virtio"/>
    </disk>
    <disk type="file" device="cdrom">
      <target dev="hda" bus="ide"/>
      <readonly/>
    </disk>
    <controller type="usb" index="0" model="ich9-ehci1"/>
    <controller type="usb" index="0" model="ich9-uhci1">
      <master startport="0"/>
    </controller>
    <controller type="usb" index="0" model="ich9-uhci2">
      <master startport="2"/>
    </controller>
    <controller type="usb" index="0" model="ich9-uhci3">
      <master startport="4"/>
    </controller>
    <interface type="network">
      <source network="default"/>
      <mac address="52:54:00:22:19:06"/>
      <model type="virtio"/>
    </interface>
    <input type="tablet" bus="usb"/>
    <graphics type="spice" port="-1" tlsPort="-1" autoport="yes">
      <image compression="off"/>
    </graphics>
    <console type="pty"/>
    <channel type="unix">
      <source mode="bind"/>
      <target type="virtio" name="org.qemu.guest_agent.0"/>
    </channel>
    <channel type="spicevmc">
      <target type="virtio" name="com.redhat.spice.0"/>
    </channel>
    <sound model="ich6"/>
    <video>
      <model type="qxl"/>
    </video>
    <redirdev bus="usb" type="spicevmc"/>
    <redirdev bus="usb" type="spicevmc"/>
    <rng model="virtio">
      <backend model="random">/dev/urandom</backend>
    </rng>
  </devices>
</domain>
</code></pre>

Note:
Can you read this? No.  Right, that's the point.  What you are
seeing here is a 150-line XML document.

libvirt is used by virt-manager, virt-install and many other
virtualization systems to manage VMs.  In libvirt, VM
configuration is represented using XML.  What I want you to see
here is the amount of low-level detail that is represented at
this layer.


## Next layer:

<table class="layers">
<tr><td>management app</td></tr>
<tr><td>libvirt</td></tr>
<tr class="current"><td>QEMU</td></tr>
<tr class="hidden"><td>KVM (kernel)</td></tr>
<tr class="hidden"><td>Hardware (CPU)</td></tr>
</table>


## QEMU interface (command-line)

<pre style="font-size: 0.55em"><code data-trim>
# /usr/bin/qemu-kvm \
> -name guest=fedora28,debug-threads=on \
> -S \
> -object secret,id=masterKey0,format=raw,file=/var/lib/libvirt/qemu/domain-41-fedora28/master-key.aes \
> -machine pc-i440fx-2.10,accel=kvm,usb=off,vmport=off,dump-guest-core=off \
> -cpu Skylake-Client \
> -m 1024 \
> -realtime mlock=off \
> -smp 2,sockets=2,cores=1,threads=1 \
> -uuid f79dd672-248b-4598-9c4a-e1090235f132 \
> -no-user-config \
> -nodefaults \
> -chardev socket,id=charmonitor,path=/var/lib/libvirt/qemu/domain-41-fedora28/monitor.sock,server,nowait \
> -mon chardev=charmonitor,id=monitor,mode=control \
> -rtc base=utc,driftfix=slew \
> -global kvm-pit.lost_tick_policy=delay \
> -no-hpet \
> -no-reboot \
> -global PIIX4_PM.disable_s3=1 \
> -global PIIX4_PM.disable_s4=1 \
> -boot strict=on \
> -kernel /var/lib/libvirt/boot/virtinst-vmlinuz.dPrnLR \
> -initrd /var/lib/libvirt/boot/virtinst-initrd.img.hrYI8n \
> -device ich9-usb-ehci1,id=usb,bus=pci.0,addr=0x5.0x7 \
> -device ich9-usb-uhci1,masterbus=usb.0,firstport=0,bus=pci.0,multifunction=on,addr=0x5 \
> -device ich9-usb-uhci2,masterbus=usb.0,firstport=2,bus=pci.0,addr=0x5.0x1 \
> -device ich9-usb-uhci3,masterbus=usb.0,firstport=4,bus=pci.0,addr=0x5.0x2 \
> -device virtio-serial-pci,id=virtio-serial0,bus=pci.0,addr=0x6 \
> -drive file=/var/lib/libvirt/images/fedora28.qcow2,format=qcow2,if=none,id=drive-virtio-disk0 \
> -device virtio-blk-pci,scsi=off,bus=pci.0,addr=0x7,drive=drive-virtio-disk0,id=virtio-disk0,bootindex=1 \
> -drive file=/home/ehabkost/Downloads/Fedora-Workstation-Live-x86_64-28-1.1.iso,format=raw,if=none,id=drive-ide0-0-0,readonly=on \
> -device ide-cd,bus=ide.0,unit=0,drive=drive-ide0-0-0,id=ide0-0-0 \
> -netdev tap,fd=26,id=hostnet0,vhost=on,vhostfd=28 \
> -device virtio-net-pci,netdev=hostnet0,id=net0,mac=52:54:00:ee:2f:dd,bus=pci.0,addr=0x3 \
> -chardev pty,id=charserial0 \
> -device isa-serial,chardev=charserial0,id=serial0 \
> -chardev socket,id=charchannel0,path=/var/lib/libvirt/qemu/channel/target/domain-41-fedora28/org.qemu.guest_agent.0,server,nowait \
> -device virtserialport,bus=virtio-serial0.0,nr=1,chardev=charchannel0,id=channel0,name=org.qemu.guest_agent.0 \
> -chardev spicevmc,id=charchannel1,name=vdagent \
> -device virtserialport,bus=virtio-serial0.0,nr=2,chardev=charchannel1,id=channel1,name=com.redhat.spice.0 \
> -device usb-tablet,id=input0,bus=usb.0,port=1 \
> -spice port=5900,addr=127.0.0.1,disable-ticketing,image-compression=off,seamless-migration=on \
> -device qxl-vga,id=video0,ram_size=67108864,vram_size=67108864,vram64_size_mb=0,vgamem_mb=16,max_outputs=1,bus=pci.0,addr=0x2 \
> -device intel-hda,id=sound0,bus=pci.0,addr=0x4 \
> -device hda-duplex,id=sound0-codec0,bus=sound0.0,cad=0 \
> -chardev spicevmc,id=charredir0,name=usbredir \
> -device usb-redir,chardev=charredir0,id=redir0,bus=usb.0,port=2 \
> -chardev spicevmc,id=charredir1,name=usbredir \
> -device usb-redir,chardev=charredir1,id=redir1,bus=usb.0,port=3 \
> -device virtio-balloon-pci,id=balloon0,bus=pci.0,addr=0x8 \
> -object rng-random,id=objrng0,filename=/dev/urandom \
> -device virtio-rng-pci,rng=objrng0,id=rng0,bus=pci.0,addr=0x9 \
> -msg timestamp=on
</code></pre>

Note:
O QEMU é uma ferramenta de linha de comando.


## QEMU interface (QMP)

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


## Next layer:

<table class="layers">
<tr><td>management app</td></tr>
<tr><td>libvirt</td></tr>
<tr><td>QEMU (userspace)</td></tr>
<tr class="current"><td>KVM (kernel)</td></tr>
<tr class="hidden"><td>Hardware (CPU)</td></tr>
</table>

Note:
Now things are getting more interesting.  We're moving from
userspace to the Linux kernel.


## KVM interface

<pre><code class="c" data-trim>
fd = open("/dev/kvm", ...);
vmfd = ioctl(kvm, KVM_CREATE_VM, ...);
vcpufd = ioctl(vmfd, KVM_CREATE_VCPU, ...);
while (1) {
    ioctl(vcpufd, KVM_RUN, ...);
}
</code></pre>

Note:
This is how the KVM API looks like.  Of course a huge amount of
detail is omitted here and this code wont' work the way it is.

This just illustrates the very basic steps: userspace opens the
/dev/kvm special device file, uses the ioctl() system call to
create file descriptors that represent the VM, the VCPU, and runs
the VCPU in a loop.


## Next layer:

<table class="layers">
<tr><td>management app</td></tr>
<tr><td>libvirt</td></tr>
<tr><td>QEMU (userspace)</td></tr>
<tr><td>KVM (kernel)</td></tr>
<tr class="current"><td>Hardware (CPU)</td></tr>
</table>

Note:
Now we're at the last layer: the hardware itself.


## Hardware (CPU) interfaces

<table>
<tr><td></td><td><b>VMX</b> (Intel)                                </td><td><b>SVM</b> (AMD)                        </td></tr>
<tr><td>Setup</td><td>Virtal Machine Control Structure (**VMCS**) </td><td>Virtal Machine Control Block (**VMCB**) </td></tr>
<tr><td>Launch</td><td>**`VMLAUNCH`**                              </td><td>**`VMRUN`**                             </td></tr>
<tr><td>Resume</td><td>**`VMRESUME`**                              </td><td>**`VMRUN`**                             </td></tr>
</table>


## The Layers

<table class="layers">
<tr class="visible"><td>management app</td></tr>
<tr class="visible"><td>libvirt</td></tr>
<tr class="visible"><td>QEMU (userspace)</td></tr>
<tr class="visible"><td>KVM (kernel)</td></tr>
<tr class="visible"><td>Hardware (CPU)</td></tr>
</table>

Note:


## The virtual hardware

<img src="qemu-kvm.png" style="width: 75%; border: none;">


## The virtual hardware

<div style="display: flex;">

<div style="flex: 1;">

<h3>QEMU</h3>

<img src="computer.png" style="border: none; width: 75%;">
<!-- credit: https://pt.m.wikipedia.org/wiki/Ficheiro:Personal_computer,_exploded.svg -->
</div>

<div style="flex: 1;">

<h3>KVM</h3>

<img src="cpu.jpg" style="border: none; width: 80%;">
<!-- credit: https://pixabay.com/pt/cpu-processador-macro-caneta-pin-564771/ -->
</div>

</div>


## Userspace (QEMU) control the virtual hardware

<b>All</b> hardware emulation is configured by userspace

Note:
Um ponto relevante a se lembrar é o seguinte: o KVM e o hardware
provém apenas os mecanismos para utilizar o hardware, mas
quem vai configurar e controlar o processo todo é userspace.


## Virtual hardware configuration

<pre style="font-size: 0.55em"><code data-trim>
# /usr/bin/qemu-kvm \
> -name guest=fedora28,debug-threads=on \
> -S \
> -object secret,id=masterKey0,format=raw,file=/var/lib/libvirt/qemu/domain-41-fedora28/master-key.aes \
> -machine pc-i440fx-2.10,accel=kvm,usb=off,vmport=off,dump-guest-core=off \
> -cpu Skylake-Client \
> -m 1024 \
> -realtime mlock=off \
> -smp 2,sockets=2,cores=1,threads=1 \
> -uuid f79dd672-248b-4598-9c4a-e1090235f132 \
> -no-user-config \
> -nodefaults \
> -chardev socket,id=charmonitor,path=/var/lib/libvirt/qemu/domain-41-fedora28/monitor.sock,server,nowait \
> -mon chardev=charmonitor,id=monitor,mode=control \
> -rtc base=utc,driftfix=slew \
> -global kvm-pit.lost_tick_policy=delay \
> -no-hpet \
> -no-reboot \
> -global PIIX4_PM.disable_s3=1 \
> -global PIIX4_PM.disable_s4=1 \
> -boot strict=on \
> -kernel /var/lib/libvirt/boot/virtinst-vmlinuz.dPrnLR \
> -initrd /var/lib/libvirt/boot/virtinst-initrd.img.hrYI8n \
> -device ich9-usb-ehci1,id=usb,bus=pci.0,addr=0x5.0x7 \
> -device ich9-usb-uhci1,masterbus=usb.0,firstport=0,bus=pci.0,multifunction=on,addr=0x5 \
> -device ich9-usb-uhci2,masterbus=usb.0,firstport=2,bus=pci.0,addr=0x5.0x1 \
> -device ich9-usb-uhci3,masterbus=usb.0,firstport=4,bus=pci.0,addr=0x5.0x2 \
> -device virtio-serial-pci,id=virtio-serial0,bus=pci.0,addr=0x6 \
> -drive file=/var/lib/libvirt/images/fedora28.qcow2,format=qcow2,if=none,id=drive-virtio-disk0 \
> -device virtio-blk-pci,scsi=off,bus=pci.0,addr=0x7,drive=drive-virtio-disk0,id=virtio-disk0,bootindex=1 \
> -drive file=/home/ehabkost/Downloads/Fedora-Workstation-Live-x86_64-28-1.1.iso,format=raw,if=none,id=drive-ide0-0-0,readonly=on \
> -device ide-cd,bus=ide.0,unit=0,drive=drive-ide0-0-0,id=ide0-0-0 \
> -netdev tap,fd=26,id=hostnet0,vhost=on,vhostfd=28 \
> -device virtio-net-pci,netdev=hostnet0,id=net0,mac=52:54:00:ee:2f:dd,bus=pci.0,addr=0x3 \
> -chardev pty,id=charserial0 \
> -device isa-serial,chardev=charserial0,id=serial0 \
> -chardev socket,id=charchannel0,path=/var/lib/libvirt/qemu/channel/target/domain-41-fedora28/org.qemu.guest_agent.0,server,nowait \
> -device virtserialport,bus=virtio-serial0.0,nr=1,chardev=charchannel0,id=channel0,name=org.qemu.guest_agent.0 \
> -chardev spicevmc,id=charchannel1,name=vdagent \
> -device virtserialport,bus=virtio-serial0.0,nr=2,chardev=charchannel1,id=channel1,name=com.redhat.spice.0 \
> -device usb-tablet,id=input0,bus=usb.0,port=1 \
> -spice port=5900,addr=127.0.0.1,disable-ticketing,image-compression=off,seamless-migration=on \
> -device qxl-vga,id=video0,ram_size=67108864,vram_size=67108864,vram64_size_mb=0,vgamem_mb=16,max_outputs=1,bus=pci.0,addr=0x2 \
> -device intel-hda,id=sound0,bus=pci.0,addr=0x4 \
> -device hda-duplex,id=sound0-codec0,bus=sound0.0,cad=0 \
> -chardev spicevmc,id=charredir0,name=usbredir \
> -device usb-redir,chardev=charredir0,id=redir0,bus=usb.0,port=2 \
> -chardev spicevmc,id=charredir1,name=usbredir \
> -device usb-redir,chardev=charredir1,id=redir1,bus=usb.0,port=3 \
> -device virtio-balloon-pci,id=balloon0,bus=pci.0,addr=0x8 \
> -object rng-random,id=objrng0,filename=/dev/urandom \
> -device virtio-rng-pci,rng=objrng0,id=rng0,bus=pci.0,addr=0x9 \
> -msg timestamp=on
</code></pre>


# From guest code to device emulation

One example


## Terminology

* Inside the VM:
  * **GVA**: Guest Virtual Address
  * **GPA**: Guest Physical Address
  * Guest page tables map GVAs to GPAs
* In the host:
  * **HPA**: Host Physical Address
  * **GVA**: Host Physical Address


## 1. Launch guest code

1. Userspace allocates memory for guest (HVA)
2. `ioctl(KVM_SET_USER_MEMORY_REGION, ...)`
   * Input: GPA -> HVA mapping
  * GPA -> HPA mapping is built
3. `ioctl(vcpufd, KVM_RUN, ...);`
  *  `VMLAUNCH`/`VMRESUME` (VMX) or `VMRUN` (AMD)

Note: Os passos básicos para se rodar código em uma VCPU são os
seguintes: primeiro o código em userspace precisa alocar memória
para a máquina virtual.  Em seguida as áreas de memória são
registradas com o KVM.  Com isso, o QEMU pode pedir para o KVM
rodar o código da CPU usando.  Já dentro do kernel, o KVM vai
inicializar as estruturas necessárias para o hardware, e vai
iniciar a execução do código do guest.


## 2. Guest code runs

...until it stops:

<pre class="fragment"><code class="c" data-noescape>  <mark>outw</mark>(val, uhci->io_addr + reg);</code></pre>

Note: Uma vez rodando, o o próprio hardware vai executar as
instruções da máquina virtual.  Até chegar em alguma operação que
o hardware não pode cuidar sozinho.

Por exemplo, quando o guest tenta interagir com o hardware.  O
exemplo na tela é uma linha de código de driver USB do Linux.


## 3. VM Exits

<table class="layers" class="fragment" data-fragment-index="1">
<tr><td>management app</td></tr>
<tr><td>libvirt</td></tr>
<tr><td>QEMU (userspace)</td></tr>
<tr class="current"><td>KVM (kernel)</td><td class="fragment" data-fragment-index="3" style="border: none !important; text-align: left;">— I've got this!</td></tr>
<tr class="visible"><td>Hardware (CPU)</td><td class="fragment" data-fragment-index="2" style="border: none !important; text-align: left;">— Please help!<br><code>EXIT_REASON_IO_INSTRUCTION</code></td></tr>
</table>

Note: Nesse momento acontece o que chamamos de "VM exit".  Uma
"VM exit" é quando o hardware sai do modo de execução de máquina
virtual e retorna ao sistema operacional hospedeiro.

TODO: show VM exit code.


## 4. Software emulation (KVM)

<pre><code class="c" data-trim>
while (1) {
  vcpu_run(vcpu);        /* Hardware */
  r = handle_exit(vcpu); /* Software emulation */
  if (r)
    break;
}
</code></pre>

Note: Dentro do KVM, o modelo de execução é esse: o KVM vai rodar
o código, e cada vez que houver um VM exit, ele vai tentar emular
a operação por software dentro do próprio KVM.  Algumas vezes
isso é possível, em outras vezes não.  Se o KVM for capaz de
emular a operação, ele retorna o loop e continua executando
código da VM.  Se ele não conseguir...


## 4. Exit to userspace

<table class="layers" class="fragment" data-fragment-index="1">
<tr><td>management app</td></tr>
<tr><td>libvirt</td></tr>
<tr class="current"><td>QEMU (userspace)</td><td class="fragment" data-fragment-index="3" style="border: none !important; text-align: left;">— I've got this!</td></tr>
<tr class="visible"><td>KVM (kernel)</td><td class="fragment" data-fragment-index="2" style="border: none !important; text-align: left;">— Please help!<br><code>vcpu->run.exit_reason = KVM_EXIT_IO</code></td></tr>
<tr><td>Hardware (CPU)</td></tr>
</table>

Note: vai acontecer algo parecido com o que ocorre em uma VM exit.  O kernel vai pedir ajuda para userspace lidar com a operação.

TODO: show exit code.


## 5. QEMU VCPU loop

<pre><code class="c" data-trim data-noescape>
vcpufd = ioctl(vmfd, KVM_CREATE_VCPU, ...);
struct kvm_run *run = mmap(..., <b>vcpufd</b>, 0);
while (1) {
    ioctl(vcpufd, <mark>KVM_RUN</mark>, ...);
    switch (<mark>run->exit_reason</mark>) {
        <mark>/* handle VM exit */</mark>
    }
}
</code></pre>

Note: O método mais básico para tratar uma operação da VM em
userspace é simplesmente retornar da `ioctl` `KVM_RUN`, após
preencher algumas informações em uma estrutura de dados.  Mas
note que esse não é o *único* método.  Existem meios de userspace
receber as notificações em um file descriptor chamado `ioeventfd`
em outra thread.


## 6. QEMU I/O emulation (KVM exit)

<pre><code class="c" data-trim data-noescape>
        switch (run->exit_reason) {
        case KVM_EXIT_IO:
            <mark>kvm_handle_io</mark>(run->io.port, attrs,
                          (uint8_t *)run + run->io.data_offset,
                          run->io.direction,
                          run->io.size,
                          run->io.count);
</code></pre>


## 6. QEMU I/O emulation (implementation)

<pre><code class="c" data-trim data-noescape>
static void <mark>uhci_port_write</mark>(void *opaque, hwaddr addr,
                            uint64_t val, unsigned size)
{
    UHCIState *s = opaque;

    trace_usb_uhci_mmio_writew(addr, val);

    switch(addr) {
    case 0x00:
        if ((val & UHCI_CMD_RS) && !(s->cmd & UHCI_CMD_RS)) {
            /* start frame processing */
            trace_usb_uhci_schedule_start();
            s->expire_time = qemu_clock_get_ns(QEMU_CLOCK_VIRTUAL) +
                (NANOSECONDS_PER_SECOND / FRAME_TIMER_FREQ);
            timer_mod(s->frame_timer, s->expire_time);
            s->status &= ~UHCI_STS_HCHALTED;
        } else if (!(val & UHCI_CMD_RS)) {
            s->status |= UHCI_STS_HCHALTED;
        }
</code></pre>

Note:


## Causes of VM Exits (full)

Instructions: CPUID, GETSEC, INVD, XSETBV, INVEPT, INVVPID,
VMCALL, VMCLEAR, VMLAUNCH, VMPTRLD, VMPTRST, VMRESUME, VMXOFF,
and VMXON. Conditionally: CLTS, ENCLS, HLT, IN, OUT, INVLPG,
INVPCID, LGDT, LIDT, LLDT, LTR, SGDT, SIDT, SLDT, STR, LMSW,
MONITOR, MOV from CR3, MOV from CR8, MOV to CR0, MOV to CR3, MOV
to CR4, MOV to CR8, MOV DR, MWAIT, PAUSE, RDMSR, RDPMC, RDRAND,
RDSEED, RDTSC, RDTSCP, RSM, VMREAD, VMWRITE, WBINVD, WRMSR,
XRSTORS, XSAVES. Exceptions, Triple faults, External interrupts,
NMIs, INIT signal, SIPIs, Task switches, SMIs, VMX-preemption
timer


## Nobody likes VM Exits

## They are expensive <!-- .element: class="fragment" -->

## All layers try to minimize them <!-- .element: class="fragment" -->


## Minimizing VM Exits

* Software:
  * Paravirtualization: KVM Clock, Virtio, etc.
  * Fine tuning / configuration
  * In-kernel emulation (APIC, MSRs, vhost)
  * *etc.*
* Hardware:
  * Software MMU → Hardware MMU
  * APICv
  * *etc.*

Note:
Virtualization hardware and software is always evolving to avoid
unnecessary VM Exits.  The most notable example was the
introduction of hardware-assisted MMU virtualization.  In the
past, all page table operations done by the guest operating
system caused a VM exit.


# Guest ABI and VM management


<img src="multi-host-mgmt-vm1.png" style="border: none;">
<!-- .slide: data-transition="slide-in none-out" -->


<img src="multi-host-mgmt-vm2.png" style="border: none;">
<!-- .slide: data-transition="none-in slide-out" -->


## Guest ABI guarantees

Virtual hardware stays the same:
<ul>
<li class="fragment">After host <b>software</b> changes (QEMU, kernel, libvirt)</li>
<li class="fragment">After host <b>hardware</b> changes</li>
<li class="fragment">If <b>moved to another host</b> (live or offline migration)</li>
<li class="fragment"><b>...as long as configuration is the same</b></li>
</ul>

<p class="fragment"><b>Both QEMU and libvirt guarantee this</b></p>

Note:
This is why the QEMU command-line is so huge: everything that is
visible to the guest operating system is encoded there somehow.


## Desirable guest ABI changes

* Examples: <!-- .element: class="fragment" -->
  * More efficient defaults <!-- .element: class="fragment" -->
  * Bug fixes (e.g. CPU vulnerabilities) <!-- .element: class="fragment" -->
* Explicit configuration change always required <!-- .element: class="fragment" -->
* Work in progress to make that easier <!-- .element: class="fragment" -->


## Choosing a VM configuration

<div style="display: flex;">
<div style="flex: 0.5;">
<table class="layers">
<tr class="current"><td>management</td></tr>
<tr class="visible"><td>libvirt</td></tr>
<tr class="visible"><td>QEMU</td></tr>
<tr class="visible"><td>KVM</td></tr>
<tr class="visible"><td>Hardware</td></tr>
</table>
</div>

<div style="flex: 1; margin: 1em; text-align: left;">
<ul>
<li>Not all hosts can run all configurations</li>
<li>Only <b>management software</b> can choose the best configuration</li>
<li>libvirt/QEMU/KVM only provide mechanisms, not policy</li>
</ul>
</div>

</div>

Note:
TODO: mention libosinfo/etc



# References

TODO: add references


# Thank You

https://habkost.net/talks/linuxdevbr-2018/


# Legal Notices

<p>Image credits:</p>
<ul>
<li>"layers" by theilr: https://www.flickr.com/photos/theilr/4947839133<br>
    (<a href="https://creativecommons.org/licenses/by-sa/2.0/">CC BY-SA 2.0</a>)</li>
<li>CPU: https://pixabay.com/pt/cpu-processador-macro-caneta-pin-564771/<br>
    (<a href="https://creativecommons.org/publicdomain/zero/1.0/deed.pt">CC0 1.0</a>)</li>
<li>Desktop computer: https://pt.m.wikipedia.org/wiki/Ficheiro:Personal_computer,_exploded.svg<br>
    (a href="https://creativecommons.org/licenses/by-sa/3.0/deed.pt">CC BY-SA 3.0</a>)</li>
</ul>

Note:
TODO:
* "o que é management software?"
* "o que o QEMU faz?" "o que o KVM faz?"
* retornar para linha de comando e XML, mostrar exemplos
* pelo menos 1 exemplo para cada camada
