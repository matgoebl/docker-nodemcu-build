export DOCKER_CONTEXT=rootless
DOCKER_RUN=docker run --rm -ti \
            -v $(PWD)/sdkconfig:/opt/nodemcu-firmware/sdkconfig \
            -v $(PWD)/builddir:/opt/nodemcu-firmware/build

DOCKER_IMAGE=nodemcu32-build
ESPDEV?=/dev/ttyUSB0

default:
	make image build

all: image setup build flash

image:
	time docker build -t $(DOCKER_IMAGE) .

setup__insecure:
	@echo Make mounted files writable for rootless docker build:
	touch sdkconfig
	chmod 0666 sdkconfig
	mkdir -p builddir
	chmod 0777 builddir
	sudo chmod o+rw $(ESPDEV)

config:
	$(DOCKER_RUN) $(DOCKER_IMAGE) make menuconfig

build:
	$(DOCKER_RUN) $(DOCKER_IMAGE) build-esp32

fs__doesnotwork:
	mkdir -p builddir/fs && cp -f init.lua config.lua builddir/fs
	$(DOCKER_RUN) $(DOCKER_IMAGE) bash -c \
	 '. ./sdk/esp32-esp-idf/export.sh && \
	  sdk/esp32-esp-idf/components/spiffs/spiffsgen.py --aligned-obj-ix-table --page-size=256 --obj-name-len=32 --meta-len=4 --use-magic --use-magic-len 0x70000 build/fs/ build/spiffs.bin && \
	  srec_cat -output build/nodemcu_full_0x0.bin -binary build/bootloader/bootloader.bin -binary -offset 0x1000 -fill 0xff 0x0000 0x8000 build/partition_table/partition-table.bin -binary -offset 0x8000 -fill 0xff 0x8000 0x10000 build/nodemcu.bin -binary -offset 0x10000 -fill 0xff 0x10000 0x1a0000 build/spiffs.bin -binary -offset 0x1a0000 && \
	  echo done.'
	# spiffs_create_partition_image(storage ../spiffs_image FLASH_IN_PROJECT)

flash:
	$(DOCKER_RUN) \
	 --device $(ESPDEV) --group-add daemon --privileged \
	 $(DOCKER_IMAGE) bash -c \
	 '. ./sdk/esp32-esp-idf/export.sh && \
	  esptool.py --port $(ESPDEV) flash_id && \
	  esptool.py --port $(ESPDEV) write_flash --erase-all 0x0 build/nodemcu_full_0x0.bin'

sh:
	$(DOCKER_RUN) $(DOCKER_IMAGE) bash

realclean:
	sudo rm -rf builddir
	docker image rm nodemcu32-build

.PHONY: default all image config build flash sh realclean
