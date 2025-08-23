# HMI-Encoder Service (Raspberry Pi 5)

A lightweight Python service for Raspberry Pi 5 that watches **I²C-attached buttons and rotary encoders** and publishes events over **TCP** (newline-delimited JSON). A built-in **WebSocket** control channel lets you query status, subscribe to events, and drive RGB/indicator LEDs on supported encoder boards.

> Works headless; designed to run as a `systemd` service.

---

## Table of Contents

- [Features](#features)  
- [Architecture](#architecture)  
- [Quick Start](#quick-start)  
  - [Install](#install)  
  - [Configuration](#configuration)  
  - [Run as a service](#run-as-a-service)  
- [Event & Message Formats](#event--message-formats)  
  - [TCP stream (read-only)](#tcp-stream-read-only)  
  - [WebSocket control (read/write)](#websocket-control-readwrite)  
  - [Error format](#error-format)  
- [WebSocket Command Reference](#websocket-command-reference)  
  - [ping](#ping)  
  - [get.version](#getversion)  
  - [get.devices](#getdevices)  
  - [get.state](#getstate)  
  - [sub / unsub](#sub--unsub)  
  - [led.set](#ledset)  
  - [led.rgb](#ledrgb)  
  - [led.fade](#ledfade)  
  - [encoder.zero](#encoderzero)  
  - [switch.set](#switchset)  
  - [profile.save / profile.load](#profilesave--profileload)  
  - [replay.buffer](#replaybuffer)  
- [I²C Hardware Notes](#i²c-hardware-notes)  
- [Troubleshooting](#troubleshooting)  
- [FAQ](#faq)  
- [License](#license)

---

## Features

- Reads **rotary delta**, **press**, **hold**, **release**, and **toggle** events from I²C peripherals.  
- Streams events over **TCP** as **NDJSON** (one JSON object per line).  
- Optional **WebSocket** control plane to query/command state and drive LEDs (RGB ring/indicator).  
- **State memory**: optional persistence/restore of LED states across power or “master switch” changes.  
- Pluggable I²C backends (common expanders & encoder ICs).

---

## Architecture

- **I²C Scanner** polls configured devices on bus `1` (default on Pi).  
- **Event Router** normalizes everything into a single schema.  
- **TCP Publisher** writes events to `0.0.0.0:5010` by default (read-only).  
- **WebSocket Server** (default `0.0.0.0:4020`) accepts JSON commands and can also push live events to subscribed clients.

```
[I²C buttons/encoders] → [Decoder] → [Event Bus] → TCP:5010 (NDJSON)
                                           └→ WS:4020 (control + optional event subscriptions)
```

---

## Quick Start

### Install

```bash
sudo apt update
sudo apt install -y python3 python3-pip
pip3 install --break-system-packages smbus2 websockets pyyaml
```

Enable I²C on the Pi if not already:

```bash
sudo raspi-config nonint do_i2c 0
```

### Configuration

Create `/etc/hmi-encoder.yaml`:

```yaml
tcp:
  host: 0.0.0.0
  port: 5010

ws:
  host: 0.0.0.0
  port: 4020
  buffer: 200           # how many events to keep for replay

i2c:
  bus: 1
  poll_hz: 250          # internal scan loop

devices:
  # Example: an encoder board with RGB ring at 0x40 (hypothetical driver key)
  - type: encoder_rgb
    address: 0x40
    name: main_knob
    channels:
      - id: enc1         # logical name
        steps_per_detent: 4
        led: true        # has controllable RGB ring

  # Example: a simple 8-button expander at 0x20
  - type: gpio_keys
    address: 0x20
    name: panel_keys
    pins:
      - id: btn1
      - id: btn2
      - id: btn3
      - id: btn4

persistence:
  restore_on_start: true
  restore_on_switch_on: true
  file: /var/lib/hmi-encoder/state.json
```

> You can start with just one device and add more as wiring is confirmed.

### Run as a service

`/usr/local/bin/hmi-encoder.py` (place your script here) and make it executable. Then:

`/etc/systemd/system/hmi-encoder.service`:

```ini
[Unit]
Description=HMI Encoder / Button Service (TCP+WS)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 /usr/local/bin/hmi-encoder.py --config /etc/hmi-encoder.yaml
Restart=on-failure
User=root
Group=root

[Install]
WantedBy=multi-user.target
```

Enable & start:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now hmi-encoder.service
sudo systemctl status hmi-encoder.service
```

---

## Event & Message Formats

### TCP stream (read-only)

- Protocol: **NDJSON** over TCP.  
- One object per line; clients just `readline()`.

**Example events**

```json
{"ts":"2025-08-22T17:05:02.312Z","type":"encoder","id":"enc1","delta":1,"abs":123}
{"ts":"2025-08-22T17:05:02.948Z","type":"button","id":"btn2","edge":"press"}
{"ts":"2025-08-22T17:05:03.101Z","type":"button","id":"btn2","edge":"release","dur_ms":153}
{"ts":"2025-08-22T17:05:05.410Z","type":"switch","id":"master","state":"off"}
```

Common fields:
- `ts`: ISO-8601 UTC.
- `type`: `encoder | button | switch | info | warn | error`.
- Encoder extras: `delta` (± steps), `abs` (optional running count), `clicked` (bool).
- Button extras: `edge: press|release|hold`, `dur_ms`.
- Switch extras: `state: on|off`.

### WebSocket control (read/write)

- Connect: `ws://<host>:4020/`  
- Send/recv **JSON objects**.  
- Every command returns an ACK object: `{ "ok": true|false, "cmd": "..." , ... }`  
- **You can also subscribe to live events** via WS (same schema as TCP).

**WS message envelope**

```json
{
  "cmd": "get.state",
  "args": { "verbose": true },
  "id": "a1b2"              
}
```

### Error format

```json
{ "ok": false, "error": "missing cmd", "code": "EINVAL", "id": "a1b2" }
```

Common codes: `EINVAL`, `ENODEV`, `EBUSY`, `ETIMEOUT`, `ENOTSUP`.

---

## WebSocket Command Reference

Below are the supported commands and canonical examples.

### ping

Health check; measure WS RTT.

**Tx**
```json
{ "cmd": "ping", "id": "1" }
```

**Rx**
```json
{ "ok": true, "cmd": "ping", "id": "1", "rtt_ms": 2 }
```

---

### get.version

Returns version/build and driver list.

**Tx**
```json
{ "cmd": "get.version" }
```

**Rx**
```json
{
  "ok": true,
  "cmd": "get.version",
  "version": "hmi-encoder 0.9.0",
  "drivers": ["encoder_rgb","gpio_keys"],
  "i2c_bus": 1
}
```

---

### get.devices

Enumerate configured & detected devices.

**Tx**
```json
{ "cmd": "get.devices" }
```

**Rx**
```json
{
  "ok": true,
  "cmd": "get.devices",
  "devices": [
    {"name":"main_knob","type":"encoder_rgb","address":"0x40","channels":[{"id":"enc1","led":true}]},
    {"name":"panel_keys","type":"gpio_keys","address":"0x20","pins":["btn1","btn2","btn3","btn4"]}
  ]
}
```

---

### get.state

Snapshot of current logical state (encoders, buttons, LEDs, switches).

**Tx**
```json
{ "cmd": "get.state", "args": { "verbose": true } }
```

**Rx (example)**  
```json
{
  "ok": true,
  "cmd": "get.state",
  "encoders": {"enc1":{"abs":123}},
  "buttons": {"btn1":{"pressed":false}, "btn2":{"pressed":false}},
  "switches": {"master":"on"},
  "leds": {"enc1":{"rgb":[64,128,255],"on":true}}
}
```

---

### sub / unsub

Subscribe WS connection to live events (same payloads as TCP). Optional filters.

**Tx**
```json
{ "cmd": "sub", "args": { "types": ["encoder","button","switch"] } }
```

**Rx**
```json
{ "ok": true, "cmd": "sub", "count": 3 }
```

**Unsubscribe**
```json
{ "cmd": "unsub" }
```

---

### led.set

On/off or brightness for an indicator/ring.

**Tx**
```json
{ "cmd": "led.set", "args": { "id": "enc1", "on": true, "brightness": 0.6, "persist": true } }
```

**Rx**
```json
{ "ok": true, "cmd": "led.set", "id": "enc1" }
```

Notes:
- `persist:true` records this target state so it **restores after** a power or master switch cycle (see persistence settings).

---

### led.rgb

Set solid color for an RGB-capable control.

**Tx**
```json
{ "cmd": "led.rgb", "args": { "id": "enc1", "rgb": [32, 96, 255], "persist": true } }
```

**Rx**
```json
{ "ok": true, "cmd": "led.rgb", "id": "enc1" }
```

---

### led.fade

Simple color fade (one-shot or loop).

**Tx**
```json
{
  "cmd": "led.fade",
  "args": {
    "id": "enc1",
    "from": [0,0,0],
    "to": [0,128,255],
    "ms": 800,
    "loop": false
  }
}
```

**Rx**
```json
{ "ok": true, "cmd": "led.fade", "id": "enc1" }
```

To stop an active effect:
```json
{ "cmd": "led.fade", "args": { "id": "enc1", "stop": true } }
```

---

### encoder.zero

Zero/normalize an encoder’s absolute counter.

**Tx**
```json
{ "cmd": "encoder.zero", "args": { "id": "enc1", "value": 0 } }
```

**Rx**
```json
{ "ok": true, "cmd": "encoder.zero", "id": "enc1", "abs": 0 }
```

---

### switch.set

Logical master or other latching switches that impact LED power gating.

**Tx**
```json
{ "cmd": "switch.set", "args": { "id": "master", "state": "off" } }
```

**Rx**
```json
{ "ok": true, "cmd": "switch.set", "id": "master", "state": "off" }
```

> When `master` turns **off**, hardware LED power may cut; the service caches any `persist:true` LED states to **restore** when `master` returns **on** (if `restore_on_switch_on` is enabled).

---

### profile.save / profile.load

Save or recall a named snapshot of LED/encoder states.

**Save**
```json
{ "cmd": "profile.save", "args": { "name": "night" } }
```

**Load**
```json
{ "cmd": "profile.load", "args": { "name": "night" } }
```

---

### replay.buffer

Emit the recent event buffer (size via `ws.buffer`).

**Tx**
```json
{ "cmd": "replay.buffer" }
```

**Rx**
```json
{ "ok": true, "cmd": "replay.buffer", "count": 120, "events": [ /* … */ ] }
```

---

## I²C Hardware Notes

- Bus: Raspberry Pi default **I²C-1** (`/dev/i2c-1`).  
- Supported classes (via driver keys):
  - `encoder_rgb` – rotary encoder with addressable RGB ring / indicator LEDs.
  - `gpio_keys` – button matrix or expander (e.g., typical 0x20/0x21 parts).
- Debounce/hold timing is handled in software; tune in config if needed.
- If you have a “master” power switch that cuts LED rail power, keep `persistence.restore_on_switch_on: true` so LEDs re-apply after power returns.

---

## Troubleshooting

- **LEDs don’t restore after switch ON**  
  Ensure you used `persist:true` on your `led.set/led.rgb` commands and `persistence.restore_on_switch_on` is enabled.
- **No events on TCP**  
  Connect with `nc <pi> 5010`. If empty, check `journalctl -u hmi-encoder -e` for I²C errors.
- **WebSocket not responding**  
  Confirm port (`sudo ss -lntp | grep 4020`) and test with a simple client:
  ```js
  const ws = new WebSocket("ws://pi.local:4020/");
  ws.onmessage = e => console.log(e.data);
  ws.onopen = _ => ws.send(JSON.stringify({cmd:"ping"}));
  ```
- **I²C timeouts**  
  Check wiring, pull-ups, and address map with `i2cdetect -y 1`.

---

## FAQ

**Q: Can I use only TCP without WebSocket?**  
A: Yes. TCP is the read-only event stream. WS is optional for control and queries.

**Q: Can I publish to MQTT instead of TCP?**  
A: The core design is transport-agnostic; you can add an MQTT publisher alongside TCP if desired.

**Q: How do I filter events by source?**  
A: Prefer WS subscriptions with `types` filters. TCP is intentionally “firehose”.

---

## License

MIT (or your preferred license).
