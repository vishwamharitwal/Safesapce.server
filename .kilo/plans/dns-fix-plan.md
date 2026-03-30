# Fix: DNS Resolution Failure on Physical Device

## Problem
The Android physical device cannot resolve `safesapceserver-production.up.railway.app` (errno=7, "No address associated with hostname"). The server is confirmed ONLINE and responding correctly from the development PC. This is a device-side DNS/network issue.

## Root Cause
The phone's DNS cannot resolve Railway's hostname. This is a network configuration issue (ISP blocking, bad DNS, VPN interference), not a code bug.

## Solution: Two-Part Fix

### Part A: Device-side (User action)
- Switch to mobile data to test
- Change phone DNS to Google DNS: `8.8.8.8` / `8.8.4.4`
- Or set Private DNS to `dns.google`
- Disable any VPN on the phone

### Part B: Code improvements (3 files)

#### 1. `lib/features/session/data/signaling_service.dart`
- **Add connectivity check** before socket connection using existing `connectivity_plus` dependency
- **Add DNS pre-check** using `InternetAddress.lookup()` to detect DNS failure early
- **Improve `onConnectError` handler** to detect `SocketException` and provide specific error messages (DNS failure vs timeout vs auth error)
- **Add `checkServerReachable()` method** that does DNS lookup + optional HTTP health check

Changes:
- Import `dart:io` (InternetAddress), `connectivity_plus`
- Add `_checkConnectivity()` method - returns error message string or null if OK
- Add `_checkDns()` method - resolves hostname, returns error or null
- Modify `connect()` to call both checks before socket init
- Modify `onConnectError` callback to detect DNS errors specifically

#### 2. `lib/features/session/presentation/pages/matchmaking_screen.dart`
- **Show SnackBar error** when connection fails with actionable message
- **Add retry button** so user can try again without going back
- **Better status message** when DNS fails: "Cannot reach server. Check your internet connection or try mobile data."

Changes:
- Modify `_startMatchmakingProcess()` to show SnackBar on failure
- Add `_retryConnection()` method

#### 3. `lib/features/home/presentation/pages/main_layout_screen.dart`
- **Add connectivity listener** to detect when network comes back and auto-reconnect signaling
- **Show offline banner** when no internet detected

Changes:
- Import `connectivity_plus`
- Listen to `Connectivity().onConnectivityChanged`
- Auto-reconnect signaling when network restores

## Files to Modify
1. `lib/features/session/data/signaling_service.dart` (lines ~142-227)
2. `lib/features/session/presentation/pages/matchmaking_screen.dart` (lines ~197-211)
3. `lib/features/home/presentation/pages/main_layout_screen.dart` (lines ~42-57)

## No new dependencies needed
- `connectivity_plus: ^7.0.0` already in pubspec.yaml
- `dart:io` InternetAddress is built-in

## Verification
1. Run `flutter analyze` to check for errors
2. Test on physical device with WiFi (should show DNS error message)
3. Switch to mobile data (should connect successfully)
4. Test on emulator (should work normally)
