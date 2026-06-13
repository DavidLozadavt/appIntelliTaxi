.PHONY: deps format format-check analyze test quality apk-release aab-release apk-install-monitor

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

# Instala APK release en dispositivo USB y monitorea overlay en logcat.
apk-install-monitor:
	flutter build apk --release
	adb install -r build/app/outputs/flutter-apk/app-release.apk
	adb logcat -c
	@echo "Monitoreando overlay… (Ctrl+C para salir)"
	adb logcat -v time DriverOverlay:I OverlayService:D IntelliTaxiDiag:I flutter:I '*:S'

aab-release:
	flutter build appbundle --release
