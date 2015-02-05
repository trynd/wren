# Wren

These days computer users are on the go. Sometimes they need to bring along not only their data, but their *entire* computing environment; sometimes more than one.

The goal of the Wren project is to provide a portable, multi-system Linux environment which delivers all the capabilities a standard desktop user needs without requiring the user to write to physical media (e.g. a hard drive) on the machine they are using.

To this end, the Wren project is currently designed around the Ubuntu 14.04.1 LTS desktop Linux environment, but the general application theory can translate to any equivalent Linux distribution.

Save data (entire machine states) can be saved on a per-user or per-project basis, allowing for multiple development environments, school coursework, and even gaming rig setups to be stored along side each other but separately on the same portable media using minimal device storage space.

## Installation and Maintenance

* There's a thorough [Installation Guide](https://github.com/trynd/wren/wiki/Installation-Guide) on the wiki with step-by-step instructions for new users.
* Advanced users may prefer the basic installation instructions in the [HOWTO](/HOWTO) file.
* Check out the [Usage Guide](https://github.com/trynd/wren/wiki/Usage) to learn more about Wren's packaged tools and boot options.
* For details on performing system and kernel upgrades, see [Upgrading Your System](https://github.com/trynd/wren/wiki/Upgrading-Your-System).

## Update Instructions

If you're currently running Wren version 0.1.x, perform the following to upgrade your existing distribution instance.

* Use wrender to build new `initrd.img-*` and `platform-*` image files and replace the existing images on the boot device in `/boot/images/` (common mount path: `/mnt/wren/00-device/boot/images/`).
  * Custom save images should also be rebuilt and replaced.
* Copy `conf/platform.conf` to the boot device's `/boot/conf/` directory, replacing the existing `platform.conf` instance.
* Reboot.

If you have any custom 0.1.x images in user save directories, they will continue to work with this distribution, but support for them will be removed in a future release. Those images should be individually upgraded after performing a distribution upgrade.

## Features

### Full In-Memory Mode

The stand-out feature for most new users is Wren's ability to boot a machine and then keep it running after the boot media has been removed.

This also allows for booting multiple machines from the same portable media and keeping them running simultaneously.

Great for LAN parties of all sorts. Pretty handy for troubleshooting too.

* **Example**

  Let's say you want to put together a little hackathon with some friends and you just happen to be carrying Wren on a USB stick configured with a full Java development suite. You plug the USB stick into your laptop and boot the save image — containing Eclipse, Maven, and whatever other tools you may be using — using the `wren-unmount` boot option.

  **Then you remove the USB stick and hand it to another developer.**

  The next developer boots up their machine using the same options and again removes the USB stick from their laptop. You're now both running identical development machines (though one of you might want to change your computer's name on the network).

  This continues on for a couple more guys and gals and all of a sudden you have yourself a full development team running the exact same software configured the exact same way.

  But what's this? Your resident designer shows up to the party! Luckily you've also preconfigured a front-end development save image — with tools like GIMP, Inkscape, Scribus, and Blender 3D — so you hand the new guy your Wren stick and tell him to boot up the "Graphics" image.

  You've just given your development team everything they need for a full day's work in less time than it'll take you to explain to them what you're working on.

### Incremental and Separate Saves, On-Demand

Unlike a traditional computing setup, the Wren environment usually manages two copies of the data you're working on; one in memory and one on disk. That means you only save to disk when *you* want to (or not at all!).

Sure, this could be considered precarious in some scenarios... like when you *really* need to save that document you're working on *every 30 seconds*... then manually writing to disk can become a huge time sink. But consider the flip side.

When you're working on some *pretty experimental stuff* — the kind of stuff that may crash your system at any moment — you may not want to save every change to disk. If you did, it could take you hours to get the system up and running again. This is where Wren ***really*** shines.

Not only can you write your changes to disk when *you* want to, but you can also write each change set to a *separate* save image, allowing you to make incremental changes and roll back a couple of steps if things go haywire.

* **Example**

  You've been doing this whole *Linux* thing for a while now and decide it's about time to try your hand at writing some device drivers (*go get 'em, tiger*).

  You don't want to keep shutting down your development environment every time something goes wrong, but you do want it to be available while you're testing to make tweaks when things are going well.

  Luckily you've booted up your development environment using the `wren-to-ram` boot option. You're still able to save to disk when you make changes, but you can also, at any time, unmount the drive and move it over to your test machine.

  So you make a few changes. Instead of loading the driver on your development machine you *save to disk* and then *unmount* and remove it from your development system. You use it to boot up your test machine using the `wren-unmount` boot option and then move it back over to your development machine for future saves. In the mean time, your test machine is now running the same environment as your development machine. You load up the driver and... *crash*. Oh well.

  You tweak a bit more on your development machine and repeat the process, but this time around things seem to be working pretty well. You open up the dev tools on your test machine and tweak the driver options until something breaks and... *crash*. Back to the drawing board.

  Rinse and repeat as many times as it takes. You'll get it there, and you'll do it far faster than you normally would because you can reboot that test machine as many times (and in as many states) as you need to.

### Compressed Disk Images and Optional Swap Space

Wren is all about saving space, both on disk and in memory (RAM).

The *root* (operating system) and *platform* (Wren) images are highly compressed and, on average, take up less than 1 GB of storage space on portable media. This enables faster boot times and fewer disk reads at the expense of a (very) little bit of processing overhead.

When Wren is run fully in-memory, the images are copied into RAM in their compressed state and only use as much RAM storage as they use on disk.

A general minimum recommendation of 2 GB of RAM is preferred to use Wren, as this is the recommended amount of RAM for comfortably running Ubuntu (the distribution around which Wren is built), though it has been successfully loaded on a machine running as little as 512 MB of RAM.

Wren itself typically uses additional RAM to store active save data, so sometimes you're going to want more memory capacity to handle running applications or large data sets. That's where *Swap* comes into play. Swap space is (usually) on-disk storage used as a kind of secondary RAM for less frequently used data that's still required be to be kept "in memory."

While you can manually add swap partitions after your operating system boots up, Wren also provides an option to mount a portable swap device/partition at boot time in case you are loading larger-than-normal disk images.

## How It Works

Wren utilizes compressed disk-image layering to enable multiple, completely separate computing instances to exist on the same media. This layering occurs at boot-time and (in a normal boot sequence) once the OS has booted, the layering is completely transparent to the end user who can interact with the disk images as little or as much as they need to.

If the boot media is removed, the system runs entirely in RAM and the running instance will simply disappear when the machine is shut down or restarted.

Wren creates an in-memory, disk-image based Linux boot environment. A read-only *root* image is created from a base installation (preferably built on a virtual machine) using the usual installer techniques. Next, a *platform* image is built (using Wren's build script, *wrender*) to provide system configuration and utility scripts, as well as to hold a copy of the Wren source code to allow for subsequent tweaking and future platform builds.

Finally, the required images and configuration files are stored to bootable media (usually a portable USB device, but a hard drive works too) providing a fresh system install which can be loaded again and again.

When the user inevitably wants to save machine state, a third image is created in the background to store the user's changes. This enables any number of system configurations to be stored on the same device. Only changes are stored in a save image — installed packages, user preferences, work files, etc. — while the bulk of the system (the *root* image) remains unchanged and ready for re-use.

## The Tech

Under the hood, Wren consists primarily of complex shell scripts, but it utilizes system calls to various other technologies — a few of which are listed below (in no particular order):

* initramfs / BusyBox
* OverlayFS
* Btrfs
* udev

Given its place in the startup stack, `initramfs` is a requirement at present, but the other technologies are somewhat interchangeable. For example, Wren was initially designed around AUFS and LVM, but those were dropped in favor of the lighter-weight OverlayFS and more feature-rich Btrfs.

## Bugs

The Wren project is still in early development. The core systems work well — *most of the time* — but there are numerous hacks and workarounds in place to patch or bypass problematic systems and conflicting packages.

We expect bugs to crop up. A lot of them. That's okay, and we urge you to find and report them. If it's something you've come across before and have a suggestion, we'd sure appreciate if you sent that info our way too.

## License

The Wren project; Copyright 2013-2015 the Wren project developers.
See the COPYRIGHT file in the top-level directory of this distribution
for individual attributions.

The Wren project is currently licensed under the terms of the
GNU General Public License as published by the Free Software Foundation,
either version 3 of the License, or (at your option) any later version. See the LICENSE file in the top-level directory of this distribution for more information.
