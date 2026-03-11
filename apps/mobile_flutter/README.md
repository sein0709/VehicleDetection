# GreyEye Mobile

This app can run on a physical Android phone or iPhone against the local
GreyEye backend stack.

## 1. Prerequisites

- Flutter installed and working on macOS
- A phone connected to the same Wi-Fi network as this Mac
- Local backend stack already running
- For iPhone: an Apple developer signing setup in Xcode

## 2. Start the backend locally

From the repo root:

```bash
make dev-up
```

Then start the host-run services in separate shells:

```bash
cd services/auth_service && uv run uvicorn auth_service.app:app --port 8001 --reload
cd services/config_service && uv run uvicorn config_service.app:app --port 8002 --reload
cd services/ingest_service && uv run uvicorn ingest_service.app:app --port 8003 --reload
cd services/inference_worker && uv run python -m inference_worker.worker
cd services/reporting_api && uv run uvicorn reporting_api.app:app --port 8005 --reload
cd services/aggregator && uv run python -m aggregator.app
cd services/notification_service && uv run uvicorn notification_service.app:app --port 8007 --reload
```

Confirm the gateway responds:

```bash
curl http://127.0.0.1:8080/healthz
```

## 3. Find this Mac's LAN IP

Use one of:

```bash
ipconfig getifaddr en0
ipconfig getifaddr en1
```

Assume the result is `192.168.0.25`. The phone must reach:

- `http://192.168.0.25:8080`
- `ws://192.168.0.25:8080`

If this does not work from the phone browser, fix the network first. The app
will not be able to connect either.

## 4. Phone launch command

The mobile app now supports runtime API endpoints through `--dart-define`.
From `apps/mobile_flutter`:

```bash
flutter run \
  --dart-define=GREYEYE_API_BASE_URL=http://192.168.0.25:8080 \
  --dart-define=GREYEYE_WS_BASE_URL=ws://192.168.0.25:8080
```

If multiple devices are attached:

```bash
flutter devices
flutter run -d <device-id> \
  --dart-define=GREYEYE_API_BASE_URL=http://192.168.0.25:8080 \
  --dart-define=GREYEYE_WS_BASE_URL=ws://192.168.0.25:8080
```

## 5. Android-specific notes

USB:

1. Enable Developer Options on the phone
2. Enable USB debugging
3. Trust the Mac when prompted

The app is configured to allow local HTTP traffic in development.

Optional shortcut with USB-only testing:

```bash
adb reverse tcp:8080 tcp:8080
flutter run -d <android-device-id>
```

With `adb reverse`, the app can keep using the default `http://localhost:8080`.
That only applies to Android over USB, not iPhone.

## 6. iPhone-specific notes

1. Open `apps/mobile_flutter/ios/Runner.xcworkspace` in Xcode
2. Select the `Runner` target
3. Set a valid Team under Signing & Capabilities
4. Use a unique bundle identifier if needed
5. Trust the developer certificate on the device if prompted

Then run:

```bash
flutter run -d <iphone-device-id> \
  --dart-define=GREYEYE_API_BASE_URL=http://192.168.0.25:8080 \
  --dart-define=GREYEYE_WS_BASE_URL=ws://192.168.0.25:8080
```

The iOS app is configured to allow local HTTP traffic for development.

## 7. What works today

This is still a development client. The useful validation path on a phone is:

- register or log in
- create a site
- create a camera
- browse analytics and alerts against the local backend

Current limits in this repo:

- real inference quality still depends on loading real ONNX detector/classifier artifacts
- counting-line config is not automatically pushed into the worker
- some screens are still closer to scaffold quality than production quality

## 8. Troubleshooting

`SocketException` or timeouts:

- Verify the phone and Mac are on the same network
- Open `http://<mac-lan-ip>:8080/healthz` in the phone browser
- Check macOS firewall settings

Login works on desktop but not on phone:

- Make sure you are not using `localhost` in the phone build
- Re-run `flutter run` with the `--dart-define` values

Android app installs but cannot call the backend:

- Confirm the app was launched from this repo after the `usesCleartextTraffic`
  change
- If testing over USB, try `adb reverse tcp:8080 tcp:8080`

iPhone build fails before launch:

- Fix Xcode signing first
- Open the Xcode project once and let it resolve provisioning issues

## 9. Recommended command

From `apps/mobile_flutter`, replace the IP and device id:

```bash
flutter run -d <device-id> \
  --dart-define=GREYEYE_API_BASE_URL=http://<mac-lan-ip>:8080 \
  --dart-define=GREYEYE_WS_BASE_URL=ws://<mac-lan-ip>:8080
```
