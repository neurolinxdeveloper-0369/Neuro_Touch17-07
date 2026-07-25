# Gas Stove Servo Controller — App Integration Guide

This document is the contract between the ESP32 firmware in this repo and any client app that
controls it. It covers everything needed to build an app against this device: network discovery
and provisioning, every local HTTP endpoint, the backend MQTT bridge (topics, payloads, QoS), the
full status JSON schema (shared by both transports), the safety rules the app must respect, and
known gaps to design around.

If firmware behavior and this document ever disagree, the firmware (`CONNECT.h`, `MQTT_CTRL.h`,
`STSCTRL.h`, `PreferencesConfig.h`, `ServoDriver.ino`) is the source of truth — flag the mismatch
so this file gets updated.

## 1. What this device is

One or more Waveshare ST3215 serial bus servos, each mounted on its own gas stove knob, driven by
one ESP32 over a shared bus. The ESP32 automatically detects which servo IDs are physically present
(by scanning a configurable ID range) and exposes every detected servo as an independently
controllable knob — its own presets, its own live position, its own OFF→ON safety gate. See §4.1a
for how a motor is identified across the API (`id` query param / `motor_id` MQTT field) and how to
discover which IDs exist (`/status.motors`). The ESP32 exposes two parallel control surfaces that
always report the same underlying state and enforce the same safety rules:

- A **local HTTP API** (port 80, plain HTTP, no TLS, LAN-only) — §2 through §8 below.
- A **backend MQTT bridge**, once the device has internet access, to a fixed broker — §9 below.

Both are driven by the exact same firmware-side command logic, so a move commanded over MQTT is
subject to the identical OFF→ON safety gate as one commanded over HTTP, and either transport's
`/status`-equivalent payload has the same fields. There is no push/webhook mechanism on the HTTP
side — that app must poll; MQTT, by contrast, pushes status on every change plus a heartbeat (§9.4).

The valve's physical rotation order, clockwise from OFF, is **OFF → HIGH → MED → LOW** (flame
gets *lower* the further you turn — the opposite of the more common OFF→LOW→MED→HIGH layout).
This is a hardware fact, not configurable.

## 2. Network model & discovery

- The device is a normal Wi-Fi station (STA) on your LAN once configured — it does **not** host
  its own network during normal operation. It only hosts its own network (an AP) during Wi-Fi
  setup (see §3).
- Plain HTTP on port 80. No authentication, no HTTPS. Anyone on the same LAN can call any
  endpoint. Treat this as a trusted-local-network appliance, not a device safe to expose to the
  internet (don't port-forward it).
- **No mDNS / hostname discovery yet.** The device's IP is DHCP-assigned once it joins a real
  network, and the only way to find it today is reading it off its OLED screen. There is no
  `/status`-adjacent "here's my IP" broadcast and no `<name>.local` hostname. If your app needs
  reliable rediscovery after the device changes networks or gets a new DHCP lease, plan for
  this gap (e.g. a manual "enter IP" step, a network scan, or ask for mDNS to be added — it isn't
  implemented).
- During Wi-Fi setup mode, the device's own AP always uses a fixed IP: **`192.168.4.1`**. This
  is the ESP32 Arduino core's default `WiFi.softAP()` gateway address and is not configurable in
  this firmware.

## 3. Wi-Fi provisioning flow

Wi-Fi credentials are **never hardcoded** in the firmware — they're stored in NVS (flash) and
provisioned at runtime. This is the flow your app needs to drive for initial setup and for
switching the device to a different network later.

### 3.1 How the device decides its own state

On every boot:
1. It loads any previously-saved SSID/password from NVS.
2. If found, it tries to connect (STA mode), blocking for up to **20 seconds**
   (`WIFI_CONNECT_TIMEOUT_MS`).
3. If that succeeds → normal operation, `/status.provisioning` is `false`.
4. If there were no saved credentials, or the connect attempt timed out → the device opens its
   own temporary Wi-Fi network (AP mode) and waits for setup. `/status.provisioning` is `true`.

At runtime, if the device was connected and then loses the network entirely (router rebooted,
credentials went stale, etc.), it keeps retrying for up to **2 minutes**
(`WIFI_RECONNECT_FALLBACK_MS`) before automatically giving up and re-opening its setup network —
so a device that's become permanently unreachable recovers into setup mode on its own, without
needing physical access.

### 3.2 The setup network

- **SSID**: `GasKnob-XXXX`, where `XXXX` is the last 4 hex characters of the device's MAC address
  (unique per physical unit, so multiple devices in the same home don't collide). Read it from
  `/status.apSsid` while `provisioning` is `true`, or off the OLED (row 1).
- **Password**: fixed, currently `"12345678"` (`AP_PWD` in `ServoDriver.ino`). This is a shared
  factory passphrase, not secret — anyone in physical/RF range who knows it can join the setup
  network. Only Wi-Fi credential submission is reachable while in this state (see §3.4), not
  valve control.
- **Device IP on this network**: always `192.168.4.1`.

### 3.3 Submitting credentials

Once your app's device (phone/tablet) is joined to `GasKnob-XXXX`:

```
GET http://192.168.4.1/wifiSetup?ssid=<target-ssid>&password=<target-password>
```

- `ssid` is required (400 if missing/empty). `password` may be omitted for an open network.
- Values should be URL-encoded (SSIDs/passwords can contain spaces, `&`, etc).
- On success: `200 OK`, body `"OK"`. The device saves the credentials to NVS and immediately
  attempts to join that network (blocking, up to 20s). **The response is sent before the switch
  starts**, but the device's own AP will disappear shortly after as it switches to STA mode — your
  app's device will drop off `GasKnob-XXXX` around the same time it was joined to your real
  network anyway, so this is expected, not an error.
- On failure (bad password, SSID out of range, etc.): the device falls back to re-opening its
  setup AP automatically. Your app should poll `/status` afterward:
  - If it lands on a normal LAN and you can reach the device on the new network → success.
  - If `GasKnob-XXXX` reappears and `/status` (hit at `192.168.4.1` again) shows
    `provisioning: true` → the attempt failed, prompt the user to retry.
- There is also a plain HTML form at `http://192.168.4.1/` while in setup mode
  (`GET /` returns this instead of the normal control page — see §3.4) if you want a fallback UX
  that doesn't require the app, but the query-param endpoint above is what the app should call
  directly.

### 3.4 What's reachable during setup mode

While `provisioning` is `true`, **only Wi-Fi setup is possible** — this is enforced server-side,
not just hidden in a UI:

| Endpoint | Behavior while provisioning |
|---|---|
| `GET /` | Serves the Wi-Fi setup form, not the normal control page |
| `GET /status` | Works normally (this is how the app detects setup mode) |
| `GET /wifiSetup` | Works (this is the point) |
| `GET /resetWifi` | Works (see §3.5) |
| `GET /setPos`, `/setPreset`, `/calibrate` | **`403`**, body `"blocked: device is in WiFi setup mode, submit credentials via /wifiSetup first"` |

Design implication for your app: check `/status.provisioning` before showing valve controls, the
same way you already need to check `/status.state` for the OFF→ON gate (§5).

### 3.5 Switching to a different network later / re-provisioning

To move an already-configured device to a new network (new router, moved house, etc.):

```
GET http://<device's-current-IP>/resetWifi
```

- Works whether the device is currently connected or already in setup mode. No confirmation
  step — same local-network trust model as the rest of this API.
- Clears the saved credentials from NVS and immediately opens the setup AP (tearing down any
  current connection right away).
- From there, follow §3.3 again with the new network's credentials.

### 3.6 Broker handoff

This Wi-Fi flow (§3.1–§3.5) is unchanged by the MQTT bridge and remains the only way the device
gets network access in the first place. Once step 3 of §3.1 succeeds (the device joins a real STA
network), it automatically and independently starts connecting to the backend MQTT broker in the
background — see §9. Nothing about MQTT changes how provisioning works or what's reachable while
`provisioning` is `true` (§3.4); the MQTT connection simply isn't possible yet at that point, the
same way the broker isn't reachable from the device's own temporary AP.

## 4. Full endpoint reference

All endpoints are registered with `server.on(path, handler)`, which the ESP32 `WebServer` library
matches to *any* HTTP method (`HTTP_ANY`) — so `GET` and `POST` both work identically, as long as
parameters are sent as query-string args either way (there's no request-body/form parsing here).
Use plain `GET` with query-string params unless you have a specific reason not to; that's what's
documented and tested.

| Method | Path | Params | Available while provisioning? | Purpose |
|---|---|---|---|---|
| GET | `/` | — | Yes (shows setup form instead) | HTML page (not needed by the app) |
| GET | `/status` | — | Yes | Poll current state (see §5) |
| GET | `/setPos` | `pos` (int, raw ticks), `id` (optional, see §4.1a) | No (403) | Move a motor to an arbitrary position |
| GET | `/setPreset` | `name=off\|high\|med\|low`, `id` (optional) | No (403) | Move a motor to a calibrated preset |
| GET | `/calibrate` | `name=off\|high\|med\|low`, `id` (optional) | No (403) | Save a motor's current live position as that preset |
| GET | `/wifiSetup` | `ssid`, `password` (optional) | Yes | Provision Wi-Fi (§3.3) |
| GET | `/resetWifi` | — | Yes | Forget Wi-Fi, re-enter setup mode (§3.5) |

Response conventions across all endpoints:
- Success: `200`, body `"OK"` (plain text) for control endpoints; `200` + JSON body for `/status`.
- `400`: missing/invalid required parameter, body is a short plain-text reason.
- `403`: blocked by a safety/state rule (OFF→ON gate, or provisioning-mode gate), body is a
  plain-text reason meant to be shown to the user.
- `404`: `id` (or the MQTT command's `motor_id`, §9.3) doesn't refer to any servo that's ever been
  detected on the bus — body is a short plain-text reason. See §4.1a.
- There is no other `404` handling beyond `WebServer`'s default, and no other status codes are used.

### 4.1a Identifying which motor a request targets

### 4.1 `GET /status`

The core of the API — poll this continuously (the bundled web UI polls every **300ms**; that's
the recommended cadence). Full field reference:

| Field | Type | Meaning |
|---|---|---|
| `deviceId` | string | The device's MAC address with colons stripped, e.g. `"A1B2C3D4E5F6"`. This is `{device_id}` in every MQTT topic (§9.2) and the suffix of the hardware's MQTT client ID (§9.1) — read it here to construct MQTT topics/subscriptions without guessing. |
| `detected` | bool | **Primary motor** (see §4.1a) field — whether that servo responded to the last bus read. Kept for pre-multi-motor clients; new clients should read `motors[].detected` instead. `false` means the servo is disconnected/unpowered — treat the other primary-motor fields below as stale/unreliable when this is `false`. |
| `pos` | int | Primary motor's raw servo position, 0–4095 (12-bit, one full mechanical revolution). |
| `deg` | float | Primary motor's `pos` converted to degrees (`pos / 4095 * 360`), 1 decimal place. |
| `percent` | int, 0–100 | Primary motor: how far the knob has turned away from OFF, as a percentage of the furthest calibrated preset from OFF. **Not** a flame-level indicator (HIGH sits closer to OFF than LOW does) — just a generic "how far turned" readout. |
| `state` | string | Primary motor: `"off"`, `"high"`, `"med"`, or `"low"` — nearest-preset classification of the current live position. Ties resolve to `"off"` (safe default). This is what your app should check to enable/disable HIGH/MED/LOW controls (see §5). |
| `moving` | bool | Primary motor: whether the servo is currently mid-move. |
| `torque` | bool | Primary motor: whether torque is currently engaged (servo actively holding/driving position). `false` means the knob is mechanically free to turn by hand. Torque is only ever on during an in-flight commanded move — see §6. |
| `voltage` | float | Primary motor: supply voltage read from the servo, 1 decimal. |
| `temper` | int | Primary motor: servo temperature (raw units from the servo's own sensor; not independently validated/calibrated by this firmware). |
| `presetOff` | int | Primary motor: calibrated raw position for OFF. |
| `presetLow` | int | Primary motor: calibrated raw position for LOW. |
| `presetMed` | int | Primary motor: calibrated raw position for MED. |
| `presetHigh` | int | Primary motor: calibrated raw position for HIGH. |
| `motorCount` | int | How many motors are currently `detected` (responding on the bus) — may be less than `motors.length` if a previously-seen motor has temporarily stopped responding. |
| `motors` | array | One object per servo ID that's ever been detected since boot, in ascending ID order. Each object has the same shape as the primary-motor fields above, plus `id`: `{ "id", "detected", "pos", "deg", "percent", "state", "moving", "torque", "voltage", "temper", "presetOff", "presetLow", "presetMed", "presetHigh" }`. This is the multi-motor-aware source of truth — see §4.1a. |
| `wifiMode` | int | `1` = running its own setup AP, `2` = connected to a real network (STA), `3` = STA but currently disconnected/reconnecting. |
| `rssi` | int | Wi-Fi signal strength (dBm). Only meaningful when `wifiMode == 2`. |
| `provisioning` | bool | `true` while the device is in Wi-Fi setup mode (see §3). When `true`, `/setPos`/`/setPreset`/`/calibrate` are all blocked. |
| `apSsid` | string | The setup network's SSID (e.g. `"GasKnob-A1B2"`) while `provisioning` is `true`; empty string otherwise. |
| `uptimeMs` | int | Milliseconds since boot, monotonic. Confirms the device is alive and not frozen (as opposed to just "the network hop succeeded"). |
| `bootId` | int (uint32) | Random value picked once at boot. If this value changes between two polls, the device restarted since the last one — use this to detect an unexpected reboot (in-flight move state is lost on reboot; calibration is not, since it's persisted to NVS). |
| `epochTime` | int (unix seconds, UTC) | The device's own wall-clock time via NTP. Meaningless/near-zero until `timeSynced` is `true`. |
| `timeSynced` | bool | Whether NTP sync has completed. Requires the STA network to have actual internet access, not just LAN connectivity — if the network is offline/firewalled, this stays `false` forever and `epochTime` should not be trusted. Prefer the app's own clock for event timestamps when this is `false`. |
| `msg_id_ack` | string or null | `null` on every HTTP `/status` response (there's no "command" being acknowledged over HTTP — every request is already synchronous/request-response). This field only carries a real value over the MQTT bridge, where it echoes the `msg_id` of the command being acknowledged; see §9.3. Present here too because it's the same payload builder on the firmware side — don't special-case its absence. |
| `status` | string | `"success"` on every HTTP `/status` response. Over MQTT this can also be an `"ERR_..."` code — see §9.3/§9.6 for the full list. Included here for the same reason as `msg_id_ack`. |

Example response (connected, knob at HIGH):

```json
{
  "deviceId": "A1B2C3D4E5F6",
  "detected": true,
  "pos": 1900,
  "deg": 167.0,
  "percent": 33,
  "state": "high",
  "moving": false,
  "torque": false,
  "voltage": 12.1,
  "temper": 38,
  "presetOff": 2047,
  "presetLow": 1600,
  "presetMed": 1750,
  "presetHigh": 1900,
  "motorCount": 2,
  "motors": [
    {
      "id": 1, "detected": true, "pos": 1900, "deg": 167.0, "percent": 33,
      "state": "high", "moving": false, "torque": false, "voltage": 12.1, "temper": 38,
      "presetOff": 2047, "presetLow": 1600, "presetMed": 1750, "presetHigh": 1900
    },
    {
      "id": 2, "detected": true, "pos": 2100, "deg": 184.6, "percent": 0,
      "state": "off", "moving": false, "torque": false, "voltage": 12.1, "temper": 37,
      "presetOff": 2100, "presetLow": 1700, "presetMed": 1850, "presetHigh": 2000
    }
  ],
  "wifiMode": 2,
  "rssi": -52,
  "provisioning": false,
  "apSsid": "",
  "uptimeMs": 8143221,
  "bootId": 2847193044,
  "epochTime": 1752652800,
  "timeSynced": true,
  "msg_id_ack": null,
  "status": "success"
}
```

### 4.1a Identifying which motor a request targets

Every device in this firmware can drive more than one ST3215 servo, each an independently
controllable knob (its own presets, its own OFF→ON gate). The `id` field in each `motors[]` entry
above is that servo's bus ID — use it to target a specific motor with `/setPos`, `/setPreset`, and
`/calibrate` (§4.2–§4.4):

- **Omit `id` and nothing changes**: it defaults to the device's original single-motor ID
  (`GAS_SERVO_ID`, `1` unless reconfigured in firmware) — any existing integration that never
  sends `id` keeps controlling exactly the motor it always did, and the top-level `pos`/`state`/
  etc. fields keep describing that same motor (the "primary" motor — `GAS_SERVO_ID` if it's ever
  been detected, else whichever motor was detected first).
- **Discover available IDs** via `motors[].id` — one entry per motor that's ever been detected
  since boot (not just currently-responding ones; a motor that temporarily drops off the bus keeps
  its entry with `detected: false` rather than disappearing).
- Requesting an `id` that has never been detected on the bus gets `404` over HTTP, or
  `status: "ERR_UNKNOWN_MOTOR"` over MQTT (§9.6) — not `400`, since the parameter itself is
  well-formed, it just doesn't (yet) refer to a real motor.
- The OFF→ON safety gate (§5) is enforced **per motor, independently** — one knob being classified
  `"off"` never blocks moving a different knob.
- New motors are picked up automatically (no restart needed): the firmware re-sweeps its
  configured ID range every few seconds in the background.

### 4.2 `GET /setPos?pos=<int>&id=<int>`

Move a motor to an arbitrary raw position (0–4095).

- `pos` is required (400 if missing). `id` is optional — see §4.1a.
- The requested position is **clamped server-side** to that motor's calibrated OFF↔LOW span
  (whichever of its `presetOff`/`presetLow` is numerically smaller/larger defines the bounds) —
  you don't need to pre-clamp on the app side, but don't assume your exact requested value is
  always honored.
- Subject to that motor's OFF→ON safety gate (§5): `403` if it's currently classified `"off"` and
  the (possibly-clamped) target isn't also OFF.
- Subject to the provisioning gate (§3.4): `403` if `provisioning` is `true`.
- `404` if `id` doesn't refer to a detected motor (§4.1a).

### 4.3 `GET /setPreset?name=<off|high|med|low>&id=<int>`

Move a motor to one of its four calibrated presets.

- `name` is required; anything other than the four values is `400`. `id` is optional — see §4.1a.
- Subject to the same per-motor OFF→ON gate, provisioning gate, and `404` as `/setPos`.
- Moving *to* `off` is always allowed regardless of that motor's current state (remote shutoff must
  never be blocked).

### 4.4 `GET /calibrate?name=<off|high|med|low>&id=<int>`

Saves a motor's **current live position** as the named preset. Doesn't move anything — this is how
presets get set in the first place (the physical knob is turned by hand since torque is off
whenever no move is in flight; see §6).

- `name` is required; same four values as `/setPreset`, `400` otherwise. `id` is optional — see
  §4.1a.
- Not subject to the OFF→ON gate (calibration never moves the valve). **Is** subject to the
  provisioning gate and the `404` unknown-motor check.
- Persisted immediately to NVS (`Preferences`, namespace `"GasKnob"`, keyed per motor ID) —
  survives reboot/power loss.

## 5. Safety rules the app must respect

This is the part most likely to cause confusing behavior if not implemented app-side, even though
it's all enforced server-side regardless (a raw HTTP request bypassing your app's UI is blocked
the same way):

1. **OFF→ON gate, per motor**: if a given motor's knob is currently classified `state: "off"`, any
   `/setPos` or `/setPreset` request (or MQTT `setPos`/`setPreset` command, §9.3) targeting that
   same motor with a non-OFF position is rejected — `403` over HTTP, `status:
   "ERR_OFF_TO_ON_GATE"` in the MQTT ack (§9.6). Same underlying check either way
   (`gasApplySetPos`/`gasApplySetPreset` in `STSCTRL.h`), so there's no transport you can use to
   bypass it. Rationale: lighting this stove requires a human physically turning the knob past an
   ignition point — a remote command going straight from OFF to an on-position would just open the
   gas valve with nothing there to light it. This is evaluated **independently per motor** — one
   knob being OFF has no effect on any other knob. Your app should gray out HIGH/MED/LOW controls
   for a given motor whenever that motor's `state == "off"` (check the matching entry in
   `/status.motors`, §4.1a), mirroring the bundled web UI, so users get immediate feedback instead
   of an unexplained 403.
2. **OFF is always reachable**: moving *to* OFF is never blocked, regardless of a motor's current
   state. Never gate your app's OFF control on anything.
3. **Unknown-motor check**: `id` (HTTP) / `motor_id` (MQTT) must refer to a motor that's been
   detected at least once — `404` over HTTP, `status: "ERR_UNKNOWN_MOTOR"` over MQTT otherwise
   (§4.1a, §9.6).
4. **Provisioning gate**: all valve-control endpoints are blocked with `403` while
   `/status.provisioning` is `true`. Check this before showing any control UI.
5. **Nearest-preset classification, not tolerance-based**: a motor's `state` is computed by
   nearest calibrated preset, not a tolerance band — there's no distinct "in transition" state. A
   knob resting exactly between OFF and an on-position mid-hand-turn gets bucketed into whichever
   is numerically closer. Don't assume `state` transitions are debounced or hysteresis-protected.
6. **No physical flame/ignition sensor**: everything above is inferred purely from servo position.
   The device has no way to confirm gas is actually flowing or a flame is actually lit — don't
   build app UX that implies otherwise (e.g. don't say "flame is on", say "knob is set to HIGH").

## 6. Behavioral notes (torque, moves, timing)

- **Torque is only ever engaged on a motor during its own in-flight commanded move.** The rest of
  the time that motor's physical knob is free to turn by hand — this is intentional (task
  requirement: the device must never fight a human turning a knob). Don't interpret `torque: false`
  as an error state. This is entirely independent per motor.
- A commanded move (`/setPos` or `/setPreset`) typically completes within a few seconds; torque
  auto-releases as soon as that motor's servo reports "stopped" (after a short grace period), or
  unconditionally after a **4-second** hard timeout (`GAS_MOVE_TIMEOUT_MS`) as a stall safety net.
  Your app doesn't need to do anything special here — just keep polling `/status` and watch that
  motor's `moving`/`pos` settle.
- Movement speed/acceleration are fixed firmware constants (`GAS_MOVE_SPEED`, `GAS_MOVE_ACC`),
  shared by every motor and not configurable per-request.

## 7. Operational notes

- **No push notifications over HTTP.** Polling `/status` is the only way to observe state changes
  on this transport. 300ms is the recommended interval (matches the bundled web UI); there's no
  server-side rate limiting, but don't poll dramatically faster without a reason. If your app wants
  push-style updates without polling, use the MQTT bridge instead (§9) — it publishes on every
  state change plus a 30s heartbeat.
- **No request queueing, no exclusivity.** If two clients call `/setPos`/`/setPreset` for the same
  motor near-simultaneously, last write wins — there is exactly one target position per motor on
  the device, not per-client state. Treat this as a shared single-owner device (per motor).
- **Hand-built JSON, no schema versioning.** `/status`'s JSON is constructed with string
  concatenation, not a JSON library — it should still parse fine with any standard JSON parser,
  but there's no version field. If fields are added/removed in the future there's no automatic way
  to detect that from the wire format alone; re-check this document.
- **Heartbeat / liveness**: treat a successful `/status` response within your app's timeout as
  "device is online." Use `bootId` changing between polls to detect an unexpected reboot (§4.1).
- **Reboots lose in-flight state** (target position, torque-engaged state) but **not** calibration
  or saved Wi-Fi credentials (both are in NVS).

## 8. Known gaps (not implemented — design around these)

- **No mDNS / stable hostname.** See §2. The device's IP must currently be discovered manually
  (OLED screen) after joining a network.
- **No authentication of any kind.** Anyone on the LAN (or, during setup, anyone who knows the
  fixed `GasKnob-XXXX` AP password) can call every endpoint, including moving the valve.
- **No HTTPS.** All traffic, including Wi-Fi passwords sent to `/wifiSetup`, is plaintext HTTP.
  This is only ever sent over the device's own short-lived setup AP, but it's still unencrypted
  on that link.
- **`/setPos` allows arbitrary intermediate raw positions** within a motor's calibrated OFF↔LOW
  span (clamped, but not snapped to a preset). A real gas valve resting at an uncalibrated
  in-between position could mean a partially-open, un-ignited state. Not currently restricted;
  consider whether your app should snap slider/dial input to presets rather than sending raw
  intermediate values, even though the firmware will accept them.
- **No physical flame/ignition sensing** — see §5.6.
- **MQTT connection is plain TCP, no TLS.** The broker spec as given (§9.1) didn't include
  certificate/TLS parameters, so the firmware connects unencrypted to `129.121.120.144:8086`.
  Command/status traffic (including calibration positions) is visible to anything on that network
  path. Revisit if the broker adds a TLS listener.
- **No MQTT payload size guard beyond a fixed buffer.** The firmware reads incoming command
  payloads into a 256-byte buffer (plenty for the documented `{msg_id, action, value, motor_id}`
  shape) — don't send oversized payloads on `cmd/stove/{device_id}/control`, they'll be truncated.
- **Fixed motor scan range, not dynamically configurable over the API.** The firmware only detects
  servo IDs within a compiled-in range (`GAS_SCAN_ID_MIN`..`GAS_SCAN_ID_MAX` in `ServoDriver.ino`,
  currently 1–10) — a servo with an ID outside that range is invisible to `/status.motors` no
  matter what. There's no endpoint to change the range at runtime; it requires a firmware rebuild.
- **New/removed motors take up to `GAS_RESCAN_INTERVAL_MS` (currently 4s) to show up or drop out**
  of `/status.motors` — the firmware re-sweeps the full ID range on that cadence, not on every
  poll, since probing an ID with nothing attached waits out a bus read timeout. A motor that
  briefly drops off the bus keeps its `motors[]` entry (with `detected: false`) rather than
  disappearing, so its calibration is never lost by a transient disconnect.

## 9. MQTT bridge (backend/cloud communication)

This is the second control surface (§1) — a persistent MQTT connection from the device to a fixed
backend broker, alongside (not instead of) the local HTTP API in §2–§8. Implemented in
`MQTT_CTRL.h`. Only active once the device has actually joined a real Wi-Fi network (§3.6); while
in Wi-Fi setup mode there is no route to the broker.

### 9.1 Connection parameters

Both the hardware and the app must use these to talk to the same broker:

| Parameter | Value | Notes |
|---|---|---|
| Host IP | `129.121.120.144` | Static backend server IP. Plain TCP, no TLS (§8). |
| Port | `8086` | |
| Protocol | MQTT (v3.1.1) | |
| Client ID (hardware) | `STOVE_HW_<MAC_ADDRESS>` | e.g. `STOVE_HW_A1B2C3D4E5F6` — MAC with the colons stripped, uppercase hex as reported by the ESP32. This is also `{device_id}` in every topic below. |
| Client ID (app) | `STOVE_APP_<USER_ID>_<RANDOM>` | e.g. `STOVE_APP_U881_XYZ`. **App-side responsibility** — the firmware has no say in this, it's your app's own unique-per-session ID. Must be unique per connected session or the broker will kick the older session off. |
| Keep alive | 60 seconds | The hardware sends PINGREQ automatically if idle (handled by the `ArduinoMqttClient` library) — you don't need to do anything to trigger it, but your app must implement it too on its own client if it also wants to stay connected while idle. |
| QoS | 1 (at least once) | Used for every command subscription and every status publish from the hardware. Your app should publish commands at QoS 1 too, matching the "strict requirement for command reliability" from the spec. |
| Clean session (hardware) | `false` | So the hardware receives any commands the broker queued for it while briefly disconnected. The app should decide its own clean-session policy based on whether it wants queued messages replayed on reconnect. |

### 9.2 Topic structure

All topics use `{device_id}` — the device's MAC address with colons stripped (see the client ID
row above; same value, so `STOVE_HW_<MAC>`'s suffix is `{device_id}`). Read it directly from the
local HTTP API's `/status.deviceId` (§4.1) during initial pairing, before you've ever talked to
the device over MQTT — that's the recommended way to learn it, rather than guessing or
wildcard-subscribing (`tele/stove/+/status`).

| Direction | Topic | Purpose |
|---|---|---|
| App → Hardware | `cmd/stove/{device_id}/control` | App sends movement commands or calibration triggers (§9.3). |
| Hardware → App | `tele/stove/{device_id}/status` | Hardware pushes live state, position, and safety metrics (§9.4). |
| Hardware → App | `tele/stove/{device_id}/lwt` | Last Will and Testament, paired with a matching retained birth message — the broker (LWT) or the hardware itself (birth) tells subscribers whether the device is online (§9.5). |

### 9.3 Command payload (App → Hardware)

Published to `cmd/stove/{device_id}/control`, at QoS 1:

```json
{
  "msg_id": "req-987654",
  "action": "setPreset",
  "value": "high",
  "motor_id": 1
}
```

| Field | Type | Meaning |
|---|---|---|
| `msg_id` | string | Unique string generated by the app per command, used to match the ack (§9.4's `msg_id_ack`). Not required to be present, but if you omit it you won't be able to tell which command a given status push is acknowledging — `msg_id_ack` will come back `null`. |
| `action` | string | One of `setPos`, `setPreset`, `calibrate`, `requestStatus`. Anything else acks with `status: "ERR_UNKNOWN_ACTION"` (§9.6). |
| `value` | string or int, depends on `action` | For `setPreset`/`calibrate`: one of `"off"`, `"high"`, `"med"`, `"low"`. For `setPos`: an integer, 0–4095 (same raw-tick range as `/setPos?pos=`, and subject to the same server-side clamp to that motor's calibrated OFF↔LOW span). Ignored/unused for `requestStatus`. |
| `motor_id` | int, optional | Which servo (bus ID) this command targets — matches `/status.motors[].id` (§4.1a). **Omit it and it defaults to the device's original single-motor ID** (`GAS_SERVO_ID`, `1` unless reconfigured), same default-target rule as HTTP's `id` param (§4.1a). Targeting an id that's never been detected acks with `status: "ERR_UNKNOWN_MOTOR"` (§9.6). |

Every command is dispatched to the exact same firmware logic the HTTP endpoints use
(`gasApplySetPos`/`gasApplySetPreset`/`gasApplyCalibrate` in `STSCTRL.h`) — so the per-motor OFF→ON
safety gate (§5) and unknown-motor check apply identically here. `requestStatus` doesn't move
anything; it's a way to force an immediate status push (§9.4) outside the normal change/heartbeat
triggers, e.g. right after your app subscribes.

### 9.4 Status payload (Hardware → App)

Published to `tele/stove/{device_id}/status`, at QoS 1, not retained. This is the **exact same
payload** as the HTTP `/status` response (§4.1) — same fields, same types, built by the same
`gasBuildStatusJson()` function, including the `motorCount`/`motors` array (§4.1a) — so see §4.1's
field table for everything except the two ack fields called out there (`msg_id_ack`, `status`),
which are what actually vary between HTTP and
MQTT use of this payload.

The hardware publishes this payload under four conditions:

1. **Immediately upon connecting** to the broker (right after the birth message, §9.5).
2. **Whenever the physical state changes on any motor** — that motor's classified state
   (`off`/`high`/`med`/`low`), `moving`, `torque`, or `detected` flips to a different value than
   the last publish. A change on any single motor triggers one status push carrying every motor's
   current state (§4.1a), not a separate push per motor.
3. **Every 30 seconds as a heartbeat** if nothing above triggered a publish sooner (the 30s timer
   resets on any publish, not just heartbeats — so a burst of state-change publishes doesn't also
   fire a heartbeat moments later).
4. **Immediately upon receiving a command** on `cmd/stove/{device_id}/control`, acting as that
   command's ACK — this is the one case where `msg_id_ack`/`status` in the payload are meaningful;
   see below.

Example (an ack for a `setPreset` command on motor 1 that succeeded; motor 2 unaffected):

```json
{
  "deviceId": "A1B2C3D4E5F6",
  "detected": true,
  "pos": 1900,
  "deg": 167.0,
  "percent": 33,
  "state": "high",
  "moving": false,
  "torque": false,
  "voltage": 12.1,
  "temper": 38,
  "presetOff": 2047,
  "presetLow": 1600,
  "presetMed": 1750,
  "presetHigh": 1900,
  "motorCount": 2,
  "motors": [
    {
      "id": 1, "detected": true, "pos": 1900, "deg": 167.0, "percent": 33,
      "state": "high", "moving": false, "torque": false, "voltage": 12.1, "temper": 38,
      "presetOff": 2047, "presetLow": 1600, "presetMed": 1750, "presetHigh": 1900
    },
    {
      "id": 2, "detected": true, "pos": 2100, "deg": 184.6, "percent": 0,
      "state": "off", "moving": false, "torque": false, "voltage": 12.1, "temper": 37,
      "presetOff": 2100, "presetLow": 1700, "presetMed": 1850, "presetHigh": 2000
    }
  ],
  "wifiMode": 2,
  "rssi": -52,
  "provisioning": false,
  "apSsid": "",
  "uptimeMs": 8143221,
  "bootId": 2847193044,
  "epochTime": 1752652800,
  "timeSynced": true,
  "msg_id_ack": "req-987654",
  "status": "success"
}
```

- `msg_id_ack` — echoes the `msg_id` of the command this push is acknowledging. `null` (JSON
  null, not the string `"null"`) for a heartbeat or change-triggered push with no triggering
  command.
- `status` — `"success"`, or an `"ERR_..."` code if the command was rejected (§9.6). `"success"`
  on every non-ack (heartbeat/change) push too — there's no separate "device health" meaning here
  beyond the command result.
- Because the servo's own state (`pos`/`moving`/etc.) is read live at publish time, an ack always
  reflects the state *after* the command took effect (or, for a rejected command, the unchanged
  current state) — you don't need a separate read-after-write.

### 9.5 Last Will and Testament / birth message

```json
{ "online": false, "timestamp": 1752652800 }
```

Registered with the broker as the connection's LWT (retained, QoS 1) before the hardware's CONNECT
completes — if the hardware disconnects uncleanly (power loss, crash, network drop) without a
normal MQTT disconnect, the broker publishes this on `tele/stove/{device_id}/lwt` automatically on
the hardware's behalf. `timestamp` is the unix time (seconds, UTC) the LWT was *registered*, not
when the disconnect actually happened — treat it as approximate.

Immediately after a successful connect, the hardware publishes a matching **birth message** to the
same topic, retained, QoS 1:

```json
{ "online": true, "timestamp": 1752652800 }
```

Subscribe to `tele/stove/{device_id}/lwt` (with the retain flag honored, as any compliant client
does by default) to always get the device's last known online/offline state immediately on
subscribe, without waiting for the next heartbeat.

### 9.6 Status/error codes

The `status` field (§9.4) is `"success"` or one of:

| Code | Meaning |
|---|---|
| `ERR_OFF_TO_ON_GATE` | Rejected `setPos`/`setPreset`: the target motor's knob is currently OFF and the target wasn't also OFF (§5.1). |
| `ERR_UNKNOWN_PRESET` | `setPreset`/`calibrate` sent a `value` that isn't `off`/`high`/`med`/`low`. |
| `ERR_UNKNOWN_ACTION` | `action` wasn't one of `setPos`/`setPreset`/`calibrate`/`requestStatus`. |
| `ERR_UNKNOWN_MOTOR` | `motor_id` doesn't refer to any servo that's ever been detected on the bus (§4.1a) — HTTP equivalent is `404`. |
| `ERR_BAD_VALUE` | `setPos`'s `value` was missing or not a valid non-negative integer. |
| `ERR_BAD_PAYLOAD` | The message on `cmd/stove/{device_id}/control` wasn't valid JSON at all. |

These are MQTT-specific — the HTTP API (§4) reports the same underlying failures as HTTP status
codes (`400`/`403`/`404`) with a plain-text body instead, since it doesn't have a `status` field to
key off of (except `/status` itself, which always reports `"success"`, §4.1).

### 9.7 Relationship to the local HTTP API

- Both transports are live simultaneously and always agree — there's one shared set of per-motor
  state on the device (`gasMotors[]` in `STSCTRL.h`, indexed by servo id), read/written by whichever
  transport a command arrives on. A move commanded over HTTP for a given motor shows up in the next
  MQTT status push for that same motor and vice versa.
- The safety rules in §5 apply identically over MQTT — nothing about using MQTT instead of HTTP
  relaxes the OFF→ON gate or any other check.
- If your app has both a local (same-LAN) and remote (cloud) mode, you can use the HTTP API for the
  former and MQTT for the latter, or just use MQTT everywhere once the device has internet access —
  there's no functional difference in what commands are accepted.
