# Instagram Ad Skipper (Flutter) — Project Plan

Personal-use Android app. Flutter UI + native Kotlin `AccessibilityService` (Flutter project ke `android/` folder ke andar). Instagram me ads detect karke auto-skip karta hai (NoScroll jaisa).

---

## 1. Feasibility

| Item | Status |
|---|---|
| Flutter project me `android/` folder me Kotlin code likhna | Possible |
| AccessibilityService Dart me likhna | Nahi, native Kotlin hi hoga |
| Ready-made ad element data / dataset | Available nahi, khud dump karna hai |
| Feed ads detect karna | High chance |
| Reels / Stories ads detect karna | Medium, label tree me na aaye to fail |
| Full ad block (ad dikhe hi nahi) | Nahi, sirf skip (ad ~1 sec dikhega) |
| Play Store publish | Reject hoga, sideload APK only |
| iOS | Support nahi |

**Not working approaches**
- DNS / VPN blocking: ads same first-party domain se aate hain.
- Patched APK (ReVanced style): high effort, ban risk.
- Rust: zaroori nahi.

---

## 2. Approach

1. Native Kotlin `AdSkipService` Instagram ka UI tree read karti hai.
2. "Sponsored" marker wala visible node mile to swipe-up gesture dispatch karti hai.
3. Flutter UI settings, counter aur service status dikhata hai.
4. Flutter <-> Kotlin communication `MethodChannel` se.

---

## 3. Tech Stack

- Flutter (Dart): UI
- Kotlin (`android/app/src/main/kotlin/...`): `AccessibilityService`, `dispatchGesture`, `MainActivity` (channel handler)
- SharedPreferences (native side): enabled flag, skip counter
- `MethodChannel` (+ optional `EventChannel` live counter ke liye)
- minSdk 24+

---

## 4. Folder Structure

```
adskip/
|-- lib/
|   |-- main.dart                  # UI
|   |-- native_bridge.dart         # MethodChannel wrapper
|-- android/app/src/main/
|   |-- kotlin/com/example/adskip/
|   |   |-- MainActivity.kt        # MethodChannel handlers
|   |   |-- AdSkipService.kt       # AccessibilityService
|   |   |-- Prefs.kt               # SharedPreferences helper
|   |-- res/xml/
|   |   |-- accessibility_service_config.xml
|   |-- AndroidManifest.xml        # service declaration
```

---

## 5. Architecture

```
Flutter UI (main.dart)
   |-- native_bridge.dart --MethodChannel--> MainActivity.kt
                                                |-- Prefs (enabled, count)
                                                |-- open Accessibility Settings
                                                |-- isServiceEnabled()

AdSkipService.kt (AccessibilityService, alag process-level service)
   |-- onAccessibilityEvent
   |-- hasVisibleAd(root)   -> marker match
   |-- swipeUp()            -> dispatchGesture
   |-- cooldown (700 ms)
   |-- Prefs.increment()
```

**MethodChannel methods** (channel name: `adskip/native`)

| Method | Kaam |
|---|---|
| `openAccessibilitySettings` | `Settings.ACTION_ACCESSIBILITY_SETTINGS` intent |
| `isServiceEnabled` | service on hai ya nahi |
| `setEnabled(bool)` | Prefs me flag save |
| `getEnabled` | flag read |
| `getCount` | skipped ads counter read |

Counter live chahiye to app resume pe `getCount()` poll karo (simple) ya `EventChannel` lagao.

---

## 6. Build Steps

### Phase 0 — Data collection (pehle ye karo)
Ad detection ka koi public data nahi hai, khud dump karna padega.

1. `AdSkipService` me debug function likho jo `rootInActiveWindow` ka poora tree log kare:
   `className`, `text`, `contentDescription`, `viewIdResourceName`, `boundsInScreen`, `isVisibleToUser`. Logcat tag: `IGDUMP`.
2. Instagram feed me ad aane tak scroll karo, dump lo.
3. Ek normal post ka dump bhi lo.
4. Dono compare karo, jo node sirf ad me hai wahi marker hai.
5. Feed, Reels, Stories teeno ke liye repeat karo.

Alternative tools: Android Studio Layout Inspector, `adb shell uiautomator dump`.

**Decision gate:** Ad me "Sponsored" jaisa node dikha to aage badho, nahi dikha to us surface ke liye rok do.

### Phase 1 — Flutter project setup
- `flutter create adskip`
- `android/` folder Android Studio / Antigravity me kholo, package name decide karo.
- Manifest me service declare (`BIND_ACCESSIBILITY_SERVICE`).
- `res/xml/accessibility_service_config.xml` banao.

### Phase 2 — Native service (Kotlin)
- `packageNames = com.instagram.android`
- `canRetrieveWindowContent = true`, `canPerformGestures = true`
- Events: `typeWindowContentChanged`, `typeViewScrolled`
- Phase 0 ka debug dump yahin.

### Phase 3 — Detection
- Markers: `Sponsored`, `Paid partnership` (Phase 0 ke result se final karo)
- Exact match (false positive kam)
- Visible-on-screen check (`isVisibleToUser` + bounds)
- Language: Instagram English me rakho ya Hindi labels add karo

### Phase 4 — Skip action
- `dispatchGesture` swipe up (screen height 75% se 30%, ~250 ms)
- 700 ms cooldown (loop rokne ke liye)

### Phase 5 — MethodChannel bridge
- `MainActivity.kt` me `configureFlutterEngine` me channel handler.
- `native_bridge.dart` me Dart wrapper.

### Phase 6 — Flutter UI
- On/off switch
- Skipped ads counter
- Service status (enabled / disabled)
- Button: Accessibility Settings kholne ke liye (service user ko manually enable karni hogi)
- App resume pe status + count refresh (`WidgetsBindingObserver`)

### Phase 7 — Testing
- Real device only (emulator me ads reliable nahi)
- Feed, Reels, Stories alag test
- Instagram update ke baad re-test

---

## 7. Antigravity Workflow

**Antigravity kar sakta hai**
- Flutter + Kotlin dono code likhna, manifest, XML, MethodChannel wiring
- `flutter build apk`, Gradle errors fix karna
- Debug dump function likhna
- `adb install`, `adb logcat`, `adb shell uiautomator dump` chalana (phone USB/wireless debugging se connected ho)
- Log padhkar detection rule suggest karna

**Tumhe khud karna hai**
- Phone pe Instagram scroll karke ad laana
- Accessibility service enable karna
- Real device pe final test

Ek saath poora app mat maango, phase by phase do.

### Prompt templates

**Prompt 1 (setup + debug dump)**
```
Flutter project me android/ folder ke andar Kotlin AccessibilityService add karo jo
sirf com.instagram.android ke liye chale. Manifest + accessibility_service_config.xml
bhi banao. Service ek debug function me rootInActiveWindow ka poora node tree log kare
(className, text, contentDescription, viewIdResourceName, bounds, isVisibleToUser)
logcat me tag "IGDUMP" ke saath. Dump trigger karne ke liye Flutter UI me ek button
do jo MethodChannel se service ko call kare.
```

**Prompt 2 (detection)**
```
Ye logcat dump hai (ad wala aur normal post wala). Dono compare karke batao ad ko
identify karne wala reliable marker kya hai. Phir hasVisibleAd() us marker pe likho.
```

**Prompt 3 (skip)**
```
hasVisibleAd() true hone par dispatchGesture se swipe up karo, 700 ms cooldown ke
saath. Har skip pe SharedPreferences counter increment karo.
```

**Prompt 4 (bridge + UI)**
```
MethodChannel "adskip/native" banao: openAccessibilitySettings, isServiceEnabled,
setEnabled, getEnabled, getCount. Flutter me native_bridge.dart wrapper aur ek simple
screen banao: switch, counter, service status, Accessibility Settings button. App
resume pe status aur count refresh ho.
```

---

## 8. Risks

- **Instagram update:** UI/labels badalne par detection toot sakta hai, maintenance lagega.
- **Reels/Stories:** label accessibility tree me na aaye to detection impossible.
- **ToS:** Instagram automation allow nahi karta, account flag hone ka chhota risk.
- **Skip, not block:** ad ek second ke liye dikhega.
- **Battery / background kill:** kuch phones (Xiaomi, Oppo, Vivo) accessibility service kill kar dete hain, battery optimization off karni padegi.

---

## 9. Go / No-Go

- Phase 0 me ad ka marker node mila: **Go**
- Sirf feed me mila, Reels me nahi: **Partial Go** (feed ke liye banao)
- Kahin nahi mila: **No-Go** (ya WebView approach try karo)
