FROM debian:bookworm

# Install required tools
RUN apt-get update && apt-get install -y \
    squashfs-tools \
    xorriso \
    isolinux \
    libarchive-tools \
    sudo \
    systemd \
    && apt-get clean

# Set work directory
WORKDIR /work

# Copy build script and required assets
COPY entrypoint.sh /work/entrypoint.sh
COPY shellhop-client /work/shellhop-client
COPY antiX-23.2_x64-core.iso /work/antiX-23.2_x64-core.iso
COPY splash.png /work/splash.png
COPY splash.jpg /work/splash.jpg

# Make script executable
RUN chmod +x /work/entrypoint.sh

# Default command
ENTRYPOINT ["/work/entrypoint.sh"]
