.PHONY: deps format format-check analyze test quality apk apk-release aab-release apk-install-monitor

# pubspec.yaml: version: 1.0.5+2  →  dist/TaxbelUrbano-1.0.5+2.apk
APP_LABEL := TaxbelUrbano
APP_VERSION := $(shell awk '/^version:/{print $$2; exit}' pubspec.yaml)
APK_OUT := dist/$(APP_LABEL)-$(APP_VERSION).apk

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

# Genera el APK release y lo copia con nombre y versión.
# Ejemplo: dist/TaxbelUrbano-1.0.5+2.apk
apk:
	dart run tool/sync_app_version.dart
	flutter build apk --release
	@mkdir -p dist
	cp build/app/outputs/flutter-apk/app-release.apk "$(APK_OUT)"
	@echo ""
	@echo "APK listo: $(APK_OUT)"

apk-release: apk

# Instala APK release en dispositivo USB y monitorea overlay en logcat.
apk-install-monitor:
	flutter build apk --release
	adb install -r build/app/outputs/flutter-apk/app-release.apk
	adb logcat -c
	@echo "Monitoreando overlay… (Ctrl+C para salir)"
	adb logcat -v time DriverOverlay:I OverlayService:D IntelliTaxiDiag:I flutter:I '*:S'

aab-release:
	flutter build appbundle --release
