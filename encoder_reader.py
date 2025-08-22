#!/usr/bin/env python3
"""
Mstack 8-Encoder Unit Reader
Reads encoder positions and button states via I2C
Outputs data as JSON via WebSocket on port 4008
"""

import asyncio
import websockets
import json
import time
import logging
from smbus2 import SMBus
from threading import Thread, Lock
import signal
import sys

# Configuration
I2C_BUS = 1  # I2C bus 1 uses GPIO 2 (SDA) and GPIO 3 (SCL)
ENCODER_I2C_ADDR = 0x41  # Default I2C address for Mstack 8-Encoder
WEBSOCKET_PORT = 4008
UPDATE_RATE = 50  # Hz (20ms updates)

# GPIO Pin Configuration for I2C1:
# Pin 3 (GPIO 2) - SDA (Data)
# Pin 5 (GPIO 3) - SCL (Clock)
# Pin 2 - 5V Power
# Pin 6 - Ground

# Logging setup
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class EncoderUnit:
    """Interface for Mstack 8-Encoder Unit via I2C"""
    
    def __init__(self, i2c_bus=I2C_BUS, i2c_addr=ENCODER_I2C_ADDR):
        self.bus = SMBus(i2c_bus)
        self.addr = i2c_addr
        self.lock = Lock()
        self.encoder_values = [0] * 8
        self.button_states = [False] * 8
        self.last_encoder_values = [0] * 8
        
        # Test I2C connection
        try:
            self.bus.read_byte(self.addr)
            logger.info(f"✅ Connected to 8-Encoder Unit at I2C address 0x{self.addr:02X}")
        except Exception as e:
            logger.error(f"❌ Failed to connect to I2C device: {e}")
            raise
    
    def read_encoders(self):
        """Read all 8 encoder positions (16-bit signed values)"""
        try:
            with self.lock:
                # Read 16 bytes (8 encoders × 2 bytes each)
                data = self.bus.read_i2c_block_data(self.addr, 0x00, 16)
                
                # Convert to signed 16-bit values
                for i in range(8):
                    raw_value = (data[i*2] << 8) | data[i*2 + 1]
                    # Convert to signed 16-bit
                    if raw_value > 32767:
                        raw_value -= 65536
                    self.encoder_values[i] = raw_value
                    
        except Exception as e:
            logger.error(f"Error reading encoders: {e}")
    
    def read_buttons(self):
        """Read all 8 button states (1 byte, 1 bit per button)"""
        try:
            with self.lock:
                # Read button register (typically at offset 0x10)
                button_byte = self.bus.read_byte_data(self.addr, 0x10)
                
                # Extract individual button states
                for i in range(8):
                    self.button_states[i] = bool(button_byte & (1 << i))
                    
        except Exception as e:
            logger.error(f"Error reading buttons: {e}")
    
    def get_data(self):
        """Get current encoder and button data as dictionary"""
        with self.lock:
            # Calculate encoder deltas
            deltas = []
            for i in range(8):
                delta = self.encoder_values[i] - self.last_encoder_values[i]
                deltas.append(delta)
                self.last_encoder_values[i] = self.encoder_values[i]
            
            return {
                "timestamp": time.time(),
                "encoders": {
                    "positions": self.encoder_values.copy(),
                    "deltas": deltas
                },
                "buttons": self.button_states.copy()
            }

class EncoderWebSocketServer:
    """WebSocket server for encoder data"""
    
    def __init__(self, encoder_unit, port=WEBSOCKET_PORT):
        self.encoder_unit = encoder_unit
        self.port = port
        self.clients = set()
        self.running = False
        
    async def register_client(self, websocket, path):
        """Register a new WebSocket client"""
        self.clients.add(websocket)
        logger.info(f"📱 Client connected from {websocket.remote_address}")
        
        try:
            # Send initial data
            data = self.encoder_unit.get_data()
            await websocket.send(json.dumps(data))
            
            # Keep connection alive
            await websocket.wait_closed()
        except websockets.exceptions.ConnectionClosed:
            pass
        finally:
            self.clients.remove(websocket)
            logger.info(f"📱 Client disconnected")
    
    async def broadcast_data(self):
        """Broadcast encoder data to all connected clients"""
        if self.clients:
            data = self.encoder_unit.get_data()
            message = json.dumps(data, indent=2)
            
            # Send to all connected clients
            disconnected = []
            for client in self.clients:
                try:
                    await client.send(message)
                except websockets.exceptions.ConnectionClosed:
                    disconnected.append(client)
            
            # Remove disconnected clients
            for client in disconnected:
                self.clients.discard(client)
    
    async def start_server(self):
        """Start the WebSocket server"""
        logger.info(f"🌐 Starting WebSocket server on port {self.port}")
        
        # Start WebSocket server
        start_server = websockets.serve(self.register_client, "0.0.0.0", self.port)
        
        # Start periodic data broadcasting
        async def broadcast_loop():
            while self.running:
                await self.broadcast_data()
                await asyncio.sleep(1.0 / UPDATE_RATE)  # 50 Hz updates
        
        self.running = True
        await asyncio.gather(
            start_server,
            broadcast_loop()
        )

def data_reader_thread(encoder_unit):
    """Thread to continuously read encoder data"""
    logger.info("🔄 Starting encoder data reader thread")
    
    while True:
        try:
            encoder_unit.read_encoders()
            encoder_unit.read_buttons()
            time.sleep(1.0 / UPDATE_RATE)  # 50 Hz updates
        except KeyboardInterrupt:
            break
        except Exception as e:
            logger.error(f"Error in data reader thread: {e}")
            time.sleep(0.1)

def signal_handler(signum, frame):
    """Handle shutdown signals"""
    logger.info("🛑 Shutdown signal received")
    sys.exit(0)

async def main():
    """Main application entry point"""
    logger.info("🎛️ Starting Mstack 8-Encoder Unit Reader")
    
    # Set up signal handlers
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    try:
        # Initialize encoder unit
        encoder_unit = EncoderUnit()
        
        # Start data reader thread
        reader_thread = Thread(target=data_reader_thread, args=(encoder_unit,), daemon=True)
        reader_thread.start()
        
        # Start WebSocket server
        server = EncoderWebSocketServer(encoder_unit)
        await server.start_server()
        
    except KeyboardInterrupt:
        logger.info("🛑 Interrupted by user")
    except Exception as e:
        logger.error(f"❌ Application error: {e}")
        raise

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        logger.info("🛑 Application stopped")
