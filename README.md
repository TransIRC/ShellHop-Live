# ShellHop Live Builder

Automatically build a Debian Live ISO that boots directly into your custom ShellHop binary.

## Overview

This project wraps a Docker container and live-build setup to generate a live ISO that:

- Boots Debian Bookworm
- Autostarts `shellhop-client` at startup
- Connects to one of your configured relay nodes
- Allows users to connect without ever touching HDD or your servers directly!



