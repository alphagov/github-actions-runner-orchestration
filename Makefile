SHELL := /usr/bin/env bash
DEFAULT_GOAL := test
PHONY = clean
ONESHELL:

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

venv:
	python3.8 -m venv env;
	chmod +x ./env/bin/activate;

install-dev-dependencies:
	source ./env/bin/activate && python3.8 -m pip install -r requirements.txt -r requirements-dev.txt --upgrade

test-python-full: venv install-dev-dependencies test-python

test-python: venv
	source ./env/bin/activate && python3.8 -m doctest -f *.py;

test-scripts:
	shellcheck scripts/*.sh

test-client:
	cd ./client && npm run test

test-client-full:
	cd ./client && npm install && npm run test

test: test-python test-scripts test-client

test-full: test-python-full test-scripts test-client-full
