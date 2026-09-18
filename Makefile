# Androws - top level build entry points
# Author: Saeed x Claude

VERSION  := $(shell cat VERSION | cut -d' ' -f1)
ARCH     ?= x86_64
OUT      ?= out
IMG      := $(OUT)/androws-$(VERSION)-$(ARCH).img

.PHONY: all image broker clean run sizes deps stage

all: image

deps:
	@build/stages/00-prepare.sh

image:
	@ARCH=$(ARCH) OUT=$(OUT) build/build.sh all

stage:
	@ARCH=$(ARCH) OUT=$(OUT) build/build.sh $(S)

broker:
	@$(MAKE) -C src/broker

run: $(IMG)
	@tools/run-qemu.sh $(IMG)

sizes:
	@tools/size-report.sh $(OUT)

clean:
	@rm -rf $(OUT) work
	@$(MAKE) -C src/broker clean
