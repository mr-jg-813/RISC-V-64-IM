FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    xfce4 \
    xfce4-terminal \
    thunar \
    gedit \
    evince \
    gcc-riscv64-unknown-elf \
    picolibc-riscv64-unknown-elf\
    tigervnc-standalone-server \
    novnc \
    websockify \
    dbus-x11 \
    x11-xserver-utils \
    iverilog \
    git \
    make \
    bash \
    coreutils \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /workspace

COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 6080

CMD ["/start.sh"]
