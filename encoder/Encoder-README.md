# ShackMate 8-Encoder WebSocket Server

A high-performance Python WebSocket server for the **Mstack 8-Encoder Unit** (STM32F030) that provides real-time rotary encoder, button, and switch monitoring with advanced RGB LED control and visual effects.

> Designed for ShackMate HMI applications with WebSocket JSON interface on port 4008.

---

## Table of Contents

- [Features](#features)  
- [Hardware Support](#hardware-support)  
- [Quick Start](#quick-start)  
- [JSON Message Format](#json-message-format)  
- [WebSocket Command Reference](#websocket-command-reference)  
- [LED Control System](#led-control-system)  
- [Button Behavior](#button-behavior)  
- [Configuration](#configuration)  
- [Installation & Service](#installation--service)  
- [Troubleshooting](#troubleshooting)

---

## Features

### Core Functionality
- ✅ **8 Rotary Encoders** with detent scaling and position tracking
- ✅ **8 Buttons** with short press (toggle) and long press (reset) support
- ✅ **1 Master Switch** with global LED control
- ✅ **9 RGB LEDs** (8 encoders + 1 switch) with full color control
- ✅ **Real-time WebSocket** streaming at 80Hz
- ✅ **Change-based messaging** (no spam)
- ✅ **Dual-bank LED writing** for hardware reliability

### Advanced Features
- 🎨 **Visual Effects**: Gradient color sweeps on encoder movement
- 🔄 **Smart LED Gating**: Switch OFF = all LEDs off, switch ON = restore states
- 🎯 **Debounced Buttons**: 25ms debounce with long press detection (1000ms)
- 📐 **Detent Scaling**: Configurable counts-per-detent (default: 2)
- 🔁 **Auto-retry I2C**: Resilient communication with exponential backoff
- 💾 **LED State Persistence**: Toggle states preserved across switch cycles

---

## Hardware Support

### Mstack 8-Encoder Unit (STM32F030)
- **I2C Address**: `0x41`
- **Bus**: `1` (GPIO 2 SDA, GPIO 3 SCL)
- **Encoders**: 8 rotary encoders with push buttons
- **Switch**: 1 master switch with LED
- **LEDs**: 9 RGB LEDs (dual-bank addressing)

### Register Map
```
0x00-0x1F: Encoder counters (4 bytes each, signed int32)
0x40-0x47: Encoder reset registers
0x50-0x57: Button state registers
0x60:      Master switch register
0x70-0x8F: RGB LED control (dual-bank)
```

---

## Quick Start

### 1. Install Dependencies

```bash
pip install asyncio websockets smbus2
```

### 2. Run the Server

```bash
python3 8encoder.py
```

**Expected Output:**
```
🎛️ ShackMate 8-Encoder WS Server (repaint window) on :4008
=======================================================
[WS] Serving on ws://0.0.0.0:4008
🔍 Data loop started (80 Hz)
```

### 3. Connect via WebSocket

**JavaScript Example:**
```javascript
const ws = new WebSocket('ws://localhost:4008');

ws.onopen = () => {
    console.log('Connected to encoder server');
    
    // Request current state
    ws.send(JSON.stringify({"cmd": "get"}));
};

ws.onmessage = (event) => {
    const data = JSON.parse(event.data);
    console.log('Encoder data:', data);
    
    // Check for encoder changes
    if (data.encoders) {
        data.encoders.forEach((position, index) => {
            console.log(`Encoder ${index}: ${position}`);
        });
    }
};
```

**Python Example:**
```python
import asyncio
import websockets
import json

async def monitor_encoders():
    uri = "ws://localhost:4008"
    async with websockets.connect(uri) as websocket:
        print("Connected to encoder server")
        
        async for message in websocket:
            data = json.loads(message)
            print(f"Time: {data['time']}, Encoders: {data['encoders']}")
            
            # Detect button presses
            for i, button in enumerate(data['buttons']):
                if button == 1:
                    print(f"Button {i} pressed!")

asyncio.run(monitor_encoders())
```

---

## JSON Message Format

### Real-time Data Stream

The server continuously broadcasts JSON messages when changes occur:

```json
{
    "time": "14:30:25",
    "encoders": [0, -5, 12, 0, 0, 0, 0, 0],
    "buttons": [0, 1, 0, 0, 0, 0, 0, 0],
    "switch": 1,
    "online": 1
}
```

### Field Descriptions

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `time` | string | Current time (HH:MM:SS) | `"14:30:25"` |
| `encoders` | array[8] | Encoder positions (signed integers) | `[0, -5, 12, 0, 0, 0, 0, 0]` |
| `buttons` | array[8] | Button states (0=released, 1=pressed) | `[0, 1, 0, 0, 0, 0, 0, 0]` |
| `switch` | integer | Master switch state (0=OFF, 1=ON) | `1` |
| `online` | integer | Device connectivity (0=offline, 1=online) | `1` |

---

## WebSocket Command Reference

### Device Identification

#### `identify` - Flash LED for identification
Flashes a specific LED white for 1 second to identify the encoder.

**Command:**
```json
{"cmd": "identify", "idx": 0}
```

**Response:**
```json
{"ok": true, "cmd": "identify", "idx": 0}
```

**Example Usage:**
```javascript
// Identify encoder 3
ws.send(JSON.stringify({"cmd": "identify", "idx": 3}));
```

---

### LED Color Control

#### `set_encoder_colors` - Set custom encoder colors
Configure custom ON and OFF colors for a specific encoder.

**Command:**
```json
{
    "cmd": "set_encoder_colors",
    "idx": 0,
    "on": [0, 255, 0],
    "off": [50, 0, 0]
}
```

**Parameters:**
- `idx` (0-7): Encoder index
- `on` [r,g,b]: RGB color when encoder LED is toggled ON
- `off` [r,g,b]: RGB color when encoder LED is toggled OFF

**Example - Set encoder 0 to green/red:**
```javascript
ws.send(JSON.stringify({
    "cmd": "set_encoder_colors",
    "idx": 0,
    "on": [0, 255, 0],    // Bright green when ON
    "off": [50, 0, 0]     // Dim red when OFF
}));
```

#### `clear_encoder_colors` - Reset to default colors
Reset an encoder to use the global default colors.

**Command:**
```json
{"cmd": "clear_encoder_colors", "idx": 0}
```

#### `set_default_colors` - Set global default colors
Set the default colors used by all encoders that don't have custom colors.

**Command:**
```json
{
    "cmd": "set_default_colors",
    "on": [0, 0, 200],
    "off": [0, 0, 0]
}
```

**Example - Set all encoders to blue/black by default:**
```javascript
ws.send(JSON.stringify({
    "cmd": "set_default_colors",
    "on": [0, 0, 200],    // Blue when ON
    "off": [0, 0, 0]      // Black when OFF
}));
```

#### `set_switch_colors` - Set master switch colors
Configure the master switch LED colors.

**Command:**
```json
{
    "cmd": "set_switch_colors",
    "on": [0, 200, 0],
    "off": [200, 0, 0]
}
```

---

### Position Control

#### `reset` - Reset single encoder
Reset a specific encoder position to zero.

**Command:**
```json
{"cmd": "reset", "idx": 0}
```

**Example:**
```javascript
// Reset encoder 2 to zero
ws.send(JSON.stringify({"cmd": "reset", "idx": 2}));
```

#### `reset_all` - Reset all encoders
Reset all encoder positions to zero simultaneously.

**Command:**
```json
{"cmd": "reset_all"}
```

---

### Diagnostic Commands

#### `get` - Request current state
Request an immediate snapshot of the current device state.

**Command:**
```json
{"cmd": "get"}
```

**Response:**
```json
{
    "time": "14:30:25",
    "encoders": [0, -5, 12, 0, 0, 0, 0, 0],
    "buttons": [0, 1, 0, 0, 0, 0, 0, 0],
    "switch": 1,
    "online": 1
}
```

#### `diag_off` - Turn off all LEDs
Turn off all LEDs for diagnostic purposes.

**Command:**
```json
{"cmd": "diag_off"}
```

---

### Legacy Commands (Backward Compatibility)

#### `set_led` - Set LED color (legacy)
Set LED color (maps to encoder ON color or switch color).

**Command:**
```json
{"cmd": "set_led", "idx": 0, "rgb": [255, 0, 0]}
```

#### `clear_led` - Clear LED color (legacy)
Clear LED color (reset to default).

**Command:**
```json
{"cmd": "clear_led", "idx": 0}
```

---

## LED Control System

### Master Switch Logic

The master switch controls global LED behavior with smart gating:

- **Switch OFF (0)**: 
  - All LEDs forced off (hard override)
  - Toggle states preserved but not visible
  - Visual effects stopped
  
- **Switch ON (1)**: 
  - LEDs reflect their individual toggle states
  - Visual effects active
  - Full color control available

### Encoder LED States

Each encoder LED can be in one of three states:

1. **OFF State**: Solid color (default: black/off)
2. **ON State**: Solid color (default: blue) 
3. **FX State**: Animated gradient sweep when encoder moves

### LED Gating Policy

```
Switch OFF  → All LEDs OFF (hard override)
            → Toggle states preserved internally

Switch ON   → Toggled ON encoders = ON color (solid)
            → Toggled OFF encoders = OFF color or FX animation
            → Switch LED = Green (ON) or Red (OFF)
```

### Visual Effects System

When an encoder is rotated (and not toggled ON), it triggers a visual effect:

**Effect Phases:**
1. **Hold Phase** (80ms): Full brightness at gradient color
2. **Sweep Phase** (300ms): Color transition based on direction
3. **Fade Phase** (500ms): Fade to OFF color

**Direction-based Colors:**
- **Positive Rotation**: Blue → Cyan → Green → Yellow → Red
- **Negative Rotation**: Red → Magenta → Blue → Cyan → Green

**Example Effect Sequence:**
```
Encoder rotated clockwise:
1. Immediate blue flash (hold phase)
2. Sweep through cyan → green → yellow → red
3. Fade back to OFF color
```

---

## Button Behavior

### Short Press (< 1000ms)
- **Action**: Toggle encoder LED ON/OFF
- **LED Effect**: Immediate state change to ON or OFF color
- **Debounce**: 25ms minimum between presses
- **Visual**: Stops any active FX, sets solid color

### Long Press (≥ 1000ms)  
- **Action**: Reset encoder position to zero
- **LED Effect**: Stop any active FX, preserve toggle state
- **Hardware**: Also resets the hardware counter register
- **Feedback**: Position immediately becomes 0

### Button States in JSON
- **Real-time**: Button states reflected in every JSON message
- **Inverted Logic**: Physical pressed = 0, released = 1 (configurable)
- **Persistent**: Toggle states survive switch OFF/ON cycles

**Example Button Interactions:**
```javascript
// Monitor button presses
ws.onmessage = (event) => {
    const data = JSON.parse(event.data);
    
    data.buttons.forEach((pressed, index) => {
        if (pressed === 1) {
            console.log(`Button ${index} is currently pressed`);
        }
    });
};

// Short press detection (requires state tracking)
let previousButtons = [0,0,0,0,0,0,0,0];

ws.onmessage = (event) => {
    const data = JSON.parse(event.data);
    
    data.buttons.forEach((current, index) => {
        const previous = previousButtons[index];
        
        // Detect button release (short press)
        if (previous === 1 && current === 0) {
            console.log(`Button ${index} short press - LED toggled`);
        }
    });
    
    previousButtons = [...data.buttons];
};
```

---

## Configuration

### Key Parameters

The server can be configured by modifying these constants in `8encoder.py`:

```python
# Performance Settings
LOOP_HZ = 80              # Main loop frequency (80Hz = 12.5ms updates)
BTN_EVERY = 1             # Button check every N loops
SW_EVERY = 1              # Switch check every N loops

# Timing Settings
BUTTON_DEBOUNCE_MS = 25   # Button debounce time
LONG_PRESS_MS = 1000      # Long press threshold
COUNTS_PER_DETENT = 2     # Hardware counts per detent

# Default Colors (RGB tuples 0-255)
ON_COLOR_DEFAULT = (0, 0, 200)    # Blue
OFF_COLOR_DEFAULT = (0, 0, 0)     # Black/Off
ON_COLOR_SWITCH = (0, 200, 0)     # Green  
OFF_COLOR_SWITCH = (200, 0, 0)    # Red

# Visual Effects Timing
FX_HOLD_MS = 80           # Initial hold time at full brightness
FX_SWEEP_MS = 300         # Color sweep duration  
FX_FADE_MS = 500          # Fade out duration
FX_MIN_STEP_MS = 30       # Minimum update interval

# Hardware Settings
I2C_BUS = 1               # I2C bus number
I2C_ADDR = 0x41           # Device I2C address
WS_PORT = 4008            # WebSocket port
```

### Hardware Behavior Settings

```python
# Logic Inversion
SWITCH_INVERT = False     # Invert switch logic (False = normal)
INVERT_BUTTONS = True     # Invert button logic (True = pressed=0)

# LED Reliability
REPAINT_FRAMES_ON_SWITCH = 4  # Force repaint frames after switch ON
MAX_RETRIES = 3               # I2C retry attempts
BACKOFF_BASE = 0.002          # Retry delay base (exponential)
```

---

## Installation & Service

### Manual Installation

1. **Install system dependencies:**
   ```bash
   sudo apt update
   sudo apt install python3-pip python3-smbus
   pip3 install asyncio websockets smbus2
   ```

2. **Copy script to system location:**
   ```bash
   sudo cp 8encoder.py /usr/local/bin/shackmate-encoder
   sudo chmod +x /usr/local/bin/shackmate-encoder
   ```

3. **Create systemd service** `/etc/systemd/system/shackmate-encoder.service`:
   ```ini
   [Unit]
   Description=ShackMate 8-Encoder WebSocket Server
   After=network.target
   Wants=network.target
   
   [Service]
   Type=simple
   User=pi
   Group=i2c
   ExecStart=/usr/bin/python3 /usr/local/bin/shackmate-encoder
   Restart=always
   RestartSec=5
   StandardOutput=journal
   StandardError=journal
   
   [Install]
   WantedBy=multi-user.target
   ```

4. **Enable and start service:**
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl enable shackmate-encoder
   sudo systemctl start shackmate-encoder
   ```

### Service Management

```bash
# Check service status
sudo systemctl status shackmate-encoder

# View real-time logs  
sudo journalctl -u shackmate-encoder -f

# Restart service
sudo systemctl restart shackmate-encoder

# Stop service
sudo systemctl stop shackmate-encoder

# Disable auto-start
sudo systemctl disable shackmate-encoder
```

### Automatic Startup

To ensure the service starts automatically on boot:

```bash
# Enable service
sudo systemctl enable shackmate-encoder

# Verify enabled status
sudo systemctl is-enabled shackmate-encoder
```

---

## Troubleshooting

### I2C Communication Issues

**Check I2C device detection:**
```bash
i2cdetect -y 1
```

**Expected output:**
```
     0  1  2  3  4  5  6  7  8  9  a  b  c  d  e  f
40: -- 41 -- -- -- -- -- -- -- -- -- -- -- -- -- --
```

**Common I2C problems:**
- Device not at address 0x41: Check wiring and power
- No devices detected: Enable I2C in `raspi-config`
- Permission errors: Add user to `i2c` group

### WebSocket Connection Issues

**Test WebSocket connection:**
```bash
# Simple curl test
curl --include --no-buffer \
  --header "Connection: Upgrade" \
  --header "Upgrade: websocket" \
  --header "Sec-WebSocket-Key: SGVsbG8sIHdvcmxkIQ==" \
  --header "Sec-WebSocket-Version: 13" \
  http://localhost:4008/
```

**Check port availability:**
```bash
sudo netstat -tulnp | grep 4008
```

### LED Issues

1. **LEDs not responding**: 
   - Check master switch state (must be ON)
   - Verify I2C communication
   - Try `diag_off` command to reset

2. **Inconsistent colors**: 
   - Dual-bank writing may need firmware update
   - Check power supply (LEDs need adequate current)

3. **LEDs stuck on**: 
   - Use `diag_off` command to force reset
   - Restart service: `sudo systemctl restart shackmate-encoder`

### Encoder/Button Issues

1. **Encoders not counting**:
   - Check mechanical connection
   - Verify detent scaling (`COUNTS_PER_DETENT`)
   - Monitor raw I2C registers

2. **Buttons not responding**:
   - Check button inversion setting (`INVERT_BUTTONS`)
   - Verify debounce timing
   - Test with individual button presses

### Common Error Messages

| Error | Cause | Solution |
|-------|-------|----------|
| `Remote I/O error` | I2C communication failure | Check wiring, device power, I2C enabled |
| `OSError(121)` | Device not responding | Verify I2C address (0x41), check connections |
| `Connection refused` | WebSocket port in use | Check port 4008 availability, restart service |
| `Permission denied` | I2C access denied | Add user to `i2c` group, check `/dev/i2c-1` permissions |

### Debug Mode

Enable verbose logging by modifying the `log()` function in `8encoder.py`:

```python
def log(*a): 
    import time
    print(f"[{time.strftime('%H:%M:%S.%f')[:-3]}]", *a, flush=True)
```

**View debug output:**
```bash
sudo journalctl -u shackmate-encoder -f
```

### Performance Monitoring

Monitor system performance:

```bash
# Check CPU usage
top -p $(pgrep -f shackmate-encoder)

# Monitor I2C traffic
sudo i2cdetect -y 1
sudo i2cdump -y 1 0x41

# WebSocket connection count
sudo netstat -an | grep :4008 | grep ESTABLISHED | wc -l
```

---

## Hardware Specifications

### Electrical Requirements
- **Voltage**: 3.3V I2C logic levels
- **Current**: ~200mA max (all LEDs at full brightness)
- **Pull-ups**: 4.7kΩ recommended for I2C SDA/SCL lines
- **Power Supply**: 5V/2A minimum for full operation

### Mechanical Specifications  
- **Encoder Type**: Incremental rotary with mechanical detents
- **Button Type**: Tactile switches (normally open)
- **Switch Type**: Toggle or momentary switch with LED
- **Mounting**: Standard panel mount compatible

### Performance Specifications
- **Update Rate**: 80Hz real-time data streaming
- **Latency**: <12.5ms encoder movement to WebSocket
- **Resolution**: ±1 detent position accuracy
- **Debounce**: 25ms button debounce time
- **Range**: ±2,147,483,647 encoder counts (32-bit signed)

### I2C Specifications
- **Bus Speed**: 100kHz (standard mode)
- **Address**: 0x41 (7-bit addressing)
- **Protocol**: Standard I2C with STOP conditions
- **Retry Logic**: Exponential backoff on communication errors

---

## License

This software is part of the ShackMate project and is provided as-is for educational and non-commercial use. 

For commercial licensing or support, please contact the ShackMate development team.