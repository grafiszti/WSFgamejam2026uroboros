# syntax=docker/dockerfile:1

# Extends the Polyphase build image (which ships devkitARM, libctru, citro3d,
# tex3ds and picasso) with the packaging tools it does not provide:
#
#   makerom    - builds the final .cia from a .cxi
#   bannertool - builds the Home Menu banner.bnr from the project PNG + WAV
#   cxitool    - wraps the .3dsx produced by Polyphase into a .cxi
#
# Keeping these in a thin derived image means the expensive Polyphase image
# layers stay cached: rebuilding after a source change only re-runs this file.
#
# Build:
#   docker build -t polyphase-engine-3ds .
#
# Override the base if Polyphase is published under another tag:
#   docker build --build-arg BASE_IMAGE=myorg/polyphase-engine:latest \
#                -t polyphase-engine-3ds .
#
# Notes:
#   * bannertool 1.2.3 declares CMake 3.28 but Debian 12 ships 3.25; the sed
#     below relaxes that minimum instead of installing a second CMake.
#   * cxitool lives on the cxi-stuff branch of devkitPro/3dstools and has no
#     generated configure script, so it is compiled directly (gcc for the C
#     sources, g++ for the driver).

ARG BASE_IMAGE=polyphase-engine:latest
FROM ${BASE_IMAGE}

ARG MAKEROM_VERSION=0.19.0
ARG BANNERTOOL_VERSION=1.2.3
ARG CXITOOL_REF=cxi-stuff

USER root

RUN set -eux; \
    mkdir -p /tmp/cia-tools; \
    cd /tmp/cia-tools; \
    curl -fsSL \
        "https://github.com/3DSGuy/Project_CTR/archive/refs/tags/makerom-v${MAKEROM_VERSION}.tar.gz" \
        -o makerom.tar.gz; \
    tar -xzf makerom.tar.gz; \
    make -C "Project_CTR-makerom-v${MAKEROM_VERSION}/makerom" deps -j"$(nproc)"; \
    make -C "Project_CTR-makerom-v${MAKEROM_VERSION}/makerom" -j"$(nproc)"; \
    install -m 0755 \
        "Project_CTR-makerom-v${MAKEROM_VERSION}/makerom/bin/makerom" \
        /opt/devkitpro/tools/bin/makerom; \
    curl -fsSL \
        "https://github.com/carstene1ns/3ds-bannertool/releases/download/${BANNERTOOL_VERSION}/bannertool-${BANNERTOOL_VERSION}.tar.gz" \
        -o bannertool.tar.gz; \
    tar -xzf bannertool.tar.gz; \
    sed -i 's/cmake_minimum_required(VERSION 3.28)/cmake_minimum_required(VERSION 3.25)/' \
        "bannertool-${BANNERTOOL_VERSION}/CMakeLists.txt"; \
    cmake -S "bannertool-${BANNERTOOL_VERSION}" -B bannertool-build \
        -DCMAKE_BUILD_TYPE=Release; \
    cmake --build bannertool-build -j"$(nproc)"; \
    install -m 0755 bannertool-build/bannertool /opt/devkitpro/tools/bin/bannertool; \
    git clone --depth 1 --branch "${CXITOOL_REF}" \
        https://github.com/devkitPro/3dstools.git; \
    cd 3dstools; \
    mkdir -p /tmp/cia-tools/cxitool-obj; \
    for src in \
        src/blz.c \
        src/polarssl/aes.c src/polarssl/rsa.c src/polarssl/sha1.c \
        src/polarssl/sha2.c src/polarssl/base64.c src/polarssl/bignum.c \
        src/libyaml/api.c src/libyaml/dumper.c src/libyaml/emitter.c \
        src/libyaml/loader.c src/libyaml/parser.c src/libyaml/reader.c \
        src/libyaml/scanner.c src/libyaml/writer.c; do \
        gcc -std=gnu11 -O2 -w -I. -c "$src" \
            -o "/tmp/cia-tools/cxitool-obj/$(echo "$src" | tr / _).o"; \
    done; \
    g++ -std=gnu++11 -O2 -w -I. -DPACKAGE_STRING='"cxitool 1.2.0"' -o cxitool \
        src/cxitool.cpp src/CxiBuilder.cpp src/CxiSettings.cpp src/CxiExeFS.cpp \
        src/CxiRomFS.cpp src/3dsx_loader.cpp src/crypto.cpp src/YamlReader.cpp \
        /tmp/cia-tools/cxitool-obj/*.o; \
    install -m 0755 cxitool /opt/devkitpro/tools/bin/cxitool; \
    \
    cd /; \
    rm -rf /tmp/cia-tools; \
    command -v makerom; \
    command -v bannertool; \
    command -v cxitool

WORKDIR /game
CMD ["help"]
