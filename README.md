# 🐚 ShellHop Live Builder

Automatically build an AntiX Live ISO that boots directly into ShellHop.

## Overview

This project wraps a Docker container and live-build setup to generate a live ISO that:

- Boots AntiX-23.2_x64-Core (or another base if you so desire)
- Autostarts `shellhop-client` at startup
- Connects to one of your configured relay nodes
- Is fully customizable and reproducible


![Splash screen](./splash.png)


✨ What Is ShellHop Live?
------------------------

ShellHop Live is a minimal antiX-based ISO builder that creates a live environment where users boot directly into your `shellhop-client`---no installation, no persistence, no disk writes.

This system is designed for total isolation:

-   No trace is left on the host machine.

-   Your relay nodes are used directly via your custom `shellhop-client`.

-   Ideal for censorship avoidance, hardened environments, or quick jump-box setups.

🚀 Features
-----------

-   🐧 Boots into antiX 23.2 Core

-   ⚡ Autostarts `shellhop-client` immediately after boot

-   🔒 Supports relay hopping for secure and anonymous SSH routing

-   💾 Leaves no trace: RAM-only session, shuts down on exit

-   💡 Easy to modify or rebuild with your own client or config

📦 Requirements
---------------

Make sure your working directory includes:

-   A statically compiled `shellhop-client` binary from [TransIRC/ShellHop](https://github.com/TransIRC/ShellHop)

-   The source ISO (defaults to antiX 23.2 Core)

You can get the tested base ISO here:\
[antiX-23.2_386-core.iso](https://sourceforge.net/projects/antix-linux/files/Final/antiX-23.2/antiX-23.2_386-core.iso/download)

> 💡 You *can* experiment with other Debian/antiX-based minimal ISOs by adjusting `entrypoint.sh`.

🛠️ Building the ISO
--------------------

To build your custom ShellHop Live ISO:

Simply run: ./build-rundocker.sh 
