.SHELL := /bin/bash
.DEFAULT_GOAL := test
.PHONY = clean

build:
	mkdir -p .build/
	mkdir -p .target/scripts/
	cp ./*.py .target/
	cp ./scripts/*.sh .target/scripts/
	cd .target/ && zip -FSqr ../.build/lambda.zip .

build-dependencies:
	python3.8 -m pip install -r requirements.txt -t .target/ --upgrade

build-full: build-dependencies build

clean:
	rm -rf .build
	rm -rf .target

install-dev-dependencies:
	python3.8 -m pip install -r requirements.txt -r requirements-dev.txt

test-full: install-dev-dependencies test

test:
	python3.8 -m doctest -f *.py
	shellcheck scripts/*.sh
