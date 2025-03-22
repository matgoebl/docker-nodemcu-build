FROM debian:bookworm
LABEL maintainer="marcelstoer"

ARG DEBIAN_FRONTEND=noninteractive

# If you want to tinker with this Dockerfile on your machine do as follows:
# - git clone https://github.com/marcelstoer/docker-nodemcu-build
# - cd docker-nodemcu-build
# - vim Dockerfile
# - docker build -t docker-nodemcu-build .
# - cd <nodemcu-firmware>
# - docker run --rm -ti -v `pwd`:/opt/nodemcu-firmware docker-nodemcu-build build

# Lint the final file with https://hadolint.github.io/hadolint/

# Deleting apt-get lists is done at the very end
# hadolint ignore=DL3009
RUN apt-get update && apt-get install -y --no-install-recommends python3 python-is-python3 wget unzip git make python3-serial srecord bc xz-utils gcc ccache tzdata vim-tiny

# additionally required for ESP32 builds as per
# https://nodemcu.readthedocs.io/en/dev-esp32/build/#ubuntu
# and
# https://docs.espressif.com/projects/esp-idf/en/release-v4.4/esp32/get-started/linux-setup.html#install-prerequisites
RUN apt-get install -y --no-install-recommends flex bison gperf python3-pip python3-dev python3-setuptools cmake ninja-build ccache build-essential libffi-dev libssl-dev dfu-util libncurses5-dev libncursesw5-dev libreadline-dev libusb-1.0-0 \
 && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /var/cache/apt/archives/*

RUN adduser --system --disabled-password --shell /bin/bash --home /opt nodemcu \
 && chown nodemcu /opt
USER nodemcu

WORKDIR /opt
RUN git clone --recurse-submodules https://github.com/nodemcu/nodemcu-firmware.git --branch dev-esp32

USER root
RUN apt-get update && apt-get install -y --no-install-recommends python3-venv
USER nodemcu

WORKDIR /opt/nodemcu-firmware
RUN ./sdk/esp32-esp-idf/install.sh

RUN export IDF_PATH=/opt/nodemcu-firmware/sdk/esp32-esp-idf \
 && . ./sdk/esp32-esp-idf/export.sh \
 && python3 -m pip install --upgrade pip \
 && python3 -m pip install setuptools \
 && python3 -m pip install -r /opt/nodemcu-firmware/requirements.txt

COPY cmd.sh /opt/
COPY read.me /opt/
COPY build /opt/
COPY build-esp32 /opt/
COPY build-esp8266 /opt/
COPY configure-esp32 /opt/
COPY lfs-image /opt/

ENV PATH="/opt:${PATH}"
CMD ["/opt/cmd.sh"]
