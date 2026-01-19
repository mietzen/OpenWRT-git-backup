FROM alpine:latest

# Install required tools for building IPK packages
RUN apk add --no-cache \
    bash \
    tar \
    gzip \
    binutils \
    findutils \
    coreutils

# Create working directory
WORKDIR /build

# Set default command
CMD ["/bin/bash"]
