#!/bin/bash
set -euxo pipefail

# === CONFIGURATION ===
ISO_NAME="antiX-23.2_x64-core.iso"
OUTPUT_ISO="shellhop-antix-core.iso"
CUSTOM_BIN="shellhop-client"
SPLASH_JPG="splash.jpg"
SPLASH_PNG="splash.png"

# === PRECHECK ===
if [ ! -f "$ISO_NAME" ]; then
  echo "ERROR: '$ISO_NAME' not found. Please download the antiX core ISO first."
  exit 1
fi

# Check for required tools
REQUIRED_TOOLS=("unsquashfs" "mksquashfs" "xorriso" "chroot" "bsdtar")
for cmd in "${REQUIRED_TOOLS[@]}"; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "ERROR: Required tool '$cmd' not found."
    exit 1
  fi
done

# === PREP WORKDIR ===
rm -rf remaster-work
mkdir remaster-work && cd remaster-work

# === EXTRACT ISO ===
mkdir iso-root
bsdtar -C iso-root -xf "../$ISO_NAME"

# === LOCATE & EXTRACT THE LIVE FILESYSTEM ===
SQUASH=$(find iso-root -type f -exec du -b {} + | sort -n | grep -v "^$(stat -c%s "../$ISO_NAME") " | tail -n1 | awk '{print $2}')
if [ -z "$SQUASH" ]; then
  echo "ERROR: Could not auto-detect squashfs fragment."
  exit 1
fi

mkdir squashfs-root
unsquashfs -d squashfs-root "$SQUASH"

# === STRIP EVERYTHING NON‐ESSENTIAL ===
# Only remove what is safe for networking and basic operation!
rm -rf squashfs-root/usr/share/{man,doc,info,locale,fonts,icons,wallpapers,backgrounds,help,zoneinfo}
rm -rf squashfs-root/var/cache/apt/archives squashfs-root/var/lib/apt/lists/*

# Remove large firmware/adapters not used by most wifi/ethernet chips except common ones (Intel, Realtek, Broadcom, Atheros)
# Keep only essential networking firmware:
find squashfs-root/lib/firmware -type f ! -iname '*intel*' ! -iname '*iwlwifi*' ! -iname '*rtlwifi*' ! -iname '*realtek*' ! -iname '*ath*' ! -iname '*b43*' ! -iname '*brcm*' ! -iname '*broadcom*' -delete || true

# Remove unnecessary X11, sound, and printing packages
chroot squashfs-root apt-get purge -y xserver-xorg* xinit alsa* pulseaudio* cups* printer* || true

# Remove language prompts & display managers
chroot squashfs-root apt-get purge -y slim desktop-session-antix || true
rm -f squashfs-root/etc/init.d/language* || true
rm -f squashfs-root/usr/local/bin/language* || true
rm -f squashfs-root/usr/local/bin/desktop-session* || true
rm -f squashfs-root/lib/live/config/0030-locales || true

# Clean up apt cache again after removals
chroot squashfs-root apt-get clean
rm -rf squashfs-root/var/cache/apt/archives squashfs-root/var/lib/apt/lists/*

# === INJECT SHELLHOP CLIENT ===
cp "../$CUSTOM_BIN" squashfs-root/usr/local/bin/
chmod +x squashfs-root/usr/local/bin/$CUSTOM_BIN

# === CREATE SHELLHOP USER & SETUP HOME ===
chroot squashfs-root useradd -m -s /bin/bash ShellHop || true
chroot squashfs-root passwd -d ShellHop

mkdir -p squashfs-root/home/ShellHop/.shellhop
touch squashfs-root/home/ShellHop/.shellhop/peer_map.json
ln -sf /home/ShellHop/.shellhop/peer_map.json squashfs-root/usr/local/bin/peer_map.json
chroot squashfs-root chown -R ShellHop:ShellHop /home/ShellHop

# === ENABLE CONSOLE AUTOLOGIN VIA INITTAB ===
sed -i 's|^\(.*getty.*tty1.*\)$|T1:12345:respawn:/sbin/getty -a ShellHop 38400 tty1|' squashfs-root/etc/inittab

# === AUTO-START SHELLHOP CLIENT ON LOGIN ===
cat > squashfs-root/home/ShellHop/.bash_profile <<'EOF'
#!/bin/bash
clear
echo "Launching ShellHop..."
/usr/local/bin/shellhop-client
echo "ShellHop exited. Powering down..."
sudo /sbin/poweroff
EOF
chmod +x squashfs-root/home/ShellHop/.bash_profile
chroot squashfs-root chown ShellHop:ShellHop /home/ShellHop/.bash_profile

# === ALLOW POWEROFF WITHOUT PASSWORD ===
echo 'ShellHop ALL=(ALL) NOPASSWD: /sbin/poweroff' >> squashfs-root/etc/sudoers

# === BOOT SPLASH IMAGE ===

# ISOLINUX splash (BIOS boots)
if [ -f "../$SPLASH_JPG" ]; then
  cp "../$SPLASH_JPG" iso-root/boot/isolinux/splash.jpg
  
  # Configure for pure splash with 5 second delay
  cat > iso-root/boot/isolinux/isolinux.cfg <<'EOF'
DEFAULT linux
PROMPT 0
TIMEOUT 50  # 5 seconds (in 1/10 sec units)
UI menu.c32
MENU BACKGROUND splash.jpg
MENU TITLE Boot Menu
MENU HIDDEN
MENU HIDDENROW 18
MENU AUTOBOOT Starting ShellHop in # seconds

LABEL linux
  MENU LABEL ShellHop
  KERNEL /boot/vmlinuz
  APPEND quiet splash vga=788 loglevel=0 vt.global_cursor_default=0 initrd=/boot/initrd.gz
EOF
fi

# GRUB splash (UEFI boots)
if [ -f "../$SPLASH_PNG" ]; then
  cp "../$SPLASH_PNG" iso-root/boot/grub/splash.png
  
  # Get the actual vmlinuz and initrd paths
  VMLINUZ_PATH=$(find iso-root -name vmlinuz | head -1 | sed 's|iso-root||')
  INITRD_PATH=$(find iso-root -name initrd.gz | head -1 | sed 's|iso-root||')

  # Complete GRUB config rewrite for pure splash screen
  cat > iso-root/boot/grub/grub.cfg <<EOF
# Hide all GRUB interface elements
set menu_color_normal=black/black
set menu_color_highlight=black/black
set timeout=5
set default=0
set hidden_timeout=5
set timeout_style=hidden
set pager=1

# Load necessary modules
insmod png
insmod gfxterm
terminal_output gfxterm
set gfxmode=640x480
background_image /boot/grub/splash.png

# Minimal boot entry with no visible text
menuentry "ShellHop" --unrestricted {
    set gfxpayload=keep
    linux $VMLINUZ_PATH quiet splash loglevel=0 vt.global_cursor_default=0
    initrd $INITRD_PATH
}

# Prevent any other menus from appearing
if [ "\${timeout}" = 0 ]; then
  set timeout=5
fi
EOF

  # Verify the paths were found
  if [ -z "$VMLINUZ_PATH" ] || [ -z "$INITRD_PATH" ]; then
    echo "ERROR: Could not find kernel or initrd paths!"
    exit 1
  fi
fi

# === REPACK THE LIVE FILESYSTEM ===
rm "$SQUASH"
mksquashfs squashfs-root "$SQUASH" -comp xz -b 1048576 -Xdict-size 100% -e boot

# === REBUILD THE ISO ===
xorriso -as mkisofs \
  -o "../$OUTPUT_ISO" \
  -iso-level 3 \
  -full-iso9660-filenames \
  -volid "ShellHop" \
  -eltorito-boot boot/grub/i386-pc/eltorito.img \
  -no-emul-boot -boot-load-size 4 -boot-info-table \
  -eltorito-catalog boot/grub/boot.cat \
  -append_partition 2 0xef iso-root/boot/grub/efi.img \
  -isohybrid-gpt-basdat \
  -isohybrid-apm-hfsplus \
  iso-root

# === CLEANUP ===
cd ..
rm -rf remaster-work

echo "✅ Remastered ISO created: $OUTPUT_ISO"
du -h "$OUTPUT_ISO"
