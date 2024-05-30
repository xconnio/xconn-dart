install:
	dart pub get

lint:
	dart analyze

lint-fix:
	dart fix --apply

check-format:
	dart format --output=none --set-exit-if-changed --line-length 120 .

format:
	dart format --line-length 120 .

tests:
	dart test

run:
	dart lib/src/xconn.dart

build:
	dart compile exe lib/src/xconn.dart -o xconn.bin

build-docs:
	mkdir -p site/xconn/
	mkdocs build -d site/xconn/dart

run-docs:
	mkdocs serve

clean-docs:
	rm -rf site/
