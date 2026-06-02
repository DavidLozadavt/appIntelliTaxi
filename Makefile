.PHONY: deps format format-check analyze test quality apk-release aab-release

deps:
	flutter pub get
	dart run tool/sync_app_version.dart

format:
	dart format lib test

format-check:
	dart format --output=none --set-exit-if-changed lib test

analyze:
	dart analyze

test:
	flutter test

quality: format-check analyze test

apk-release:
	flutter build apk --release

aab-release:
	flutter build appbundle --release
