#!/usr/bin/env python3
"""
ShackMate Encoder WebSocket Server - Final Version
Clean, minimal JSON format for ShackMate HMI

Features:
- 8 Rotary encoders with clean position tracking (±1 increments)
- 8 Buttons (0-7, button 1 register 0x51)
- 1 Switch
- WebSocket interface on port 4008
- Change-based JSON messaging (no spam)
- Raw debugging output for troubleshooting
"""

import asyncio
import websockets
import json
import time
import smbus2
import signal
import sys

# Configuration
ENCODER_ADDR = 0x41
ENCODER_REG = 0x00
BUTTON_REG = 0x50
SWITCH_REG = 0x60
FIRMWARE_VERSION_REG = 0xFE
WEBSOCKET_PORT = 4008
UPDATE_RATE = 100  # Hz (10ms updates)

class EncoderServer:
    def __init__(self):
        self.bus = smbus2.SMBus(1)
        self.clients = set()
        self.running = False
        
        # Clean position tracking - starts at zero
        self.encoder_positions = [0] * 8
        self.button_states = [0] * 8  # Using 0/1 instead of True/False
        self.switch_state = 0  # Using 0/1 instead of True/False
        self.device_online = False
        
        # Previous data for change detection
        self.prev_encoder_positions = [0] * 8
        self.prev_button_states = [0] * 8
        self.prev_switch_state = 0
        self.prev_device_online = False

    def device_detection(self):
        """Test device connectivity"""
        try:
            version = self.bus.read_byte_data(ENCODER_ADDR, FIRMWARE_VERSION_REG)
            return True
        except Exception:
            return False

    def read_encoders(self):
        """Read encoder increments and update clean positions"""
        try:
            for i in range(8):
                raw_value = self.bus.read_byte_data(ENCODER_ADDR, ENCODER_REG + i)
                increment = raw_value if raw_value <= 127 else raw_value - 256
                
                if increment != 0:
                    self.encoder_positions[i] += increment
                    print(f"🔄 Encoder {i}: increment {increment}, position now {self.encoder_positions[i]}")
                    
        except Exception as e:
            raise Exception(f"Encoder read error: {e}")

    def read_buttons(self):
        """Read button states - button 1 is at register 0x51"""
        try:
            button_data = []
            
            # Button 0 (register 0x50)
            button_data.append(self.bus.read_byte_data(ENCODER_ADDR, 0x50))
            
            # Button 1 (register 0x51) - special case
            button_data.append(self.bus.read_byte_data(ENCODER_ADDR, 0x51))
            
            # Buttons 2-7 (registers 0x52-0x57)
            for i in range(2, 8):
                button_data.append(self.bus.read_byte_data(ENCODER_ADDR, BUTTON_REG + i))
            
            # Convert to 0/1 values and check for changes
            new_button_states = [1 if btn > 0 else 0 for btn in button_data]
            
            for i, (old, new) in enumerate(zip(self.button_states, new_button_states)):
                if old != new:
                    print(f"🔘 Button {i}: {old} → {new}")
            
            self.button_states = new_button_states
            
        except Exception as e:
            raise Exception(f"Button read error: {e}")

    def read_switch(self):
        """Read switch state (corrected logic - 0=off, 1=on)"""
        try:
            raw_value = self.bus.read_byte_data(ENCODER_ADDR, SWITCH_REG)
            new_switch_state = 1 if raw_value > 0 else 0
            
            if self.switch_state != new_switch_state:
                print(f"🔀 Switch: {self.switch_state} → {new_switch_state}")
            
            self.switch_state = new_switch_state
        except Exception as e:
            raise Exception(f"Switch read error: {e}")

    def has_changes(self):
        """Check if any data has changed"""
        return (
            self.encoder_positions != self.prev_encoder_positions or
            self.button_states != self.prev_button_states or
            self.switch_state != self.prev_switch_state or
            self.device_online != self.prev_device_online
        )

    def update_previous_data(self):
        """Update previous data for change detection"""
        self.prev_encoder_positions = self.encoder_positions.copy()
        self.prev_button_states = self.button_states.copy()
        self.prev_switch_state = self.switch_state
        self.prev_device_online = self.device_online

    def create_json_message(self):
        """Create simplified JSON message with 0/1 integer values"""
        return {
            "time": time.strftime("%H:%M:%S"),
            "encoders": self.encoder_positions,
            "buttons": self.button_states,
            "switch": self.switch_state,
            "online": 1 if self.device_online else 0
        }

    async def broadcast_changes(self):
        """Send data only when changes occur"""
        if self.clients and self.has_changes():
            message = json.dumps(self.create_json_message())
            
            # Send to all connected clients
            disconnected = set()
            for client in self.clients:
                try:
                    await client.send(message)
                except websockets.exceptions.ConnectionClosed:
                    disconnected.add(client)
                except Exception:
                    disconnected.add(client)
            
            # Remove disconnected clients
            self.clients -= disconnected
            
            # Update previous data
            self.update_previous_data()

    def read_all_data(self):
        """Read all sensor data"""
        try:
            self.device_online = self.device_detection()
            
            if self.device_online:
                self.read_encoders()
                self.read_buttons()
                self.read_switch()
                
        except Exception as e:
            print(f"⚠️ Read error: {e}")
            self.device_online = False

    async def data_loop(self):
        """Main data reading loop"""
        print("🔍 Starting data loop...")
        while self.running:
            try:
                self.read_all_data()
                await self.broadcast_changes()
                await asyncio.sleep(1/UPDATE_RATE)  # 100Hz updates
                
            except Exception as e:
                print(f"💥 Data loop error: {e}")
                await asyncio.sleep(0.1)

    async def handle_client(self, websocket):
        """Handle new WebSocket client"""
        print(f"🔌 Client connected: {websocket.remote_address}")
        self.clients.add(websocket)
        
        # Send initial state
        try:
            initial_message = json.dumps(self.create_json_message())
            await websocket.send(initial_message)
        except Exception:
            pass
        
        try:
            # Keep connection alive
            async for message in websocket:
                pass  # Echo or ignore client messages
        except websockets.exceptions.ConnectionClosed:
            pass
        except Exception as e:
            print(f"⚠️ Client error: {e}")
        finally:
            self.clients.discard(websocket)
            print(f"🔌 Client disconnected: {websocket.remote_address}")

    async def start_server(self):
        """Start WebSocket server"""
        print(f"🌐 Starting WebSocket server on port {WEBSOCKET_PORT}")
        
        # Start data reading loop
        self.running = True
        data_task = asyncio.create_task(self.data_loop())
        
        try:
            # Start WebSocket server
            async with websockets.serve(self.handle_client, "0.0.0.0", WEBSOCKET_PORT):
                print(f"✅ Encoder server running - WebSocket: ws://0.0.0.0:{WEBSOCKET_PORT}")
                print("🎛️ 8 Encoders | 8 Buttons | 1 Switch | Change-based JSON")
                await asyncio.Future()  # Run forever
                
        except Exception as e:
            print(f"💥 Server error: {e}")
        finally:
            self.running = False
            data_task.cancel()

    def cleanup(self):
        """Cleanup resources"""
        try:
            self.bus.close()
        except:
            pass

def signal_handler(signum, frame):
    """Handle shutdown signals"""
    print("\n🛑 Shutting down encoder server...")
    sys.exit(0)

async def main():
    # Setup signal handlers
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    server = EncoderServer()
    
    try:
        await server.start_server()
    except KeyboardInterrupt:
        print("\n🛑 Interrupted by user")
    except Exception as e:
        print(f"💥 Fatal error: {e}")
    finally:
        server.cleanup()

if __name__ == "__main__":
    print("🎛️ ShackMate Encoder Server - Clean JSON Interface")
    print("=" * 55)
    asyncio.run(main())
