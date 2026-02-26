.PHONY: deps format format-check analyze test quality

deps:
	flutter pub get

format:
	dart format lib test

format-check:
	dart format --output=none --set-exit-if-changed lib test

analyze:
	dart analyze

test:
	flutter test

quality: format-check analyze test
