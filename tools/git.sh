#!/bin/bash

create_git_repo() {
	logstep "Creating ready-to-push git repo..."
	git init -q
	git add -A
	git commit -m "$DEVICE_CODENAME: Initial TWRP device tree

	Made with SebaUbuntu's TWRP device tree generator
	Arch: $DEVICE_ARCH
	Manufacturer: $DEVICE_MANUFACTURER
	Device full name: $DEVICE_FULL_NAME
	Script version: $VERSION
	Last script commit: $LAST_COMMIT

	Signed-off-by: Sebastiano Barezzi <barezzisebastiano@gmail.com>" --author "Sebastiano Barezzi <barezzisebastiano@gmail.com>" -q
	logdone
}