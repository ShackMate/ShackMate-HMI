#!/usr/bin/env python3
"""
Test script for Mstack 8-Encoder Unit I2C connection
Tests I2C communication on GPIO 2 (SDA) and GPIO 3 (SCL)
"""

import sys
try:
    from smbus2 import SMBus
except ImportError:
    print("❌ smbus2 not installed. Run: sudo pip3 install smbus2")
    sys.exit(1)

def test_i2c_connection():
    """Test I2C connection to encoder unit"""
    
    I2C_BUS = 1  # I2C1 bus (GPIO 2/3)
    ENCODER_ADDR = 0x41  # Default encoder address
    
    print("🔍 Testing Mstack 8-Encoder Unit I2C Connection")
    print("=" * 50)
    print(f"I2C Bus: {I2C_BUS} (GPIO 2=SDA, GPIO 3=SCL)")
    print(f"Device Address: 0x{ENCODER_ADDR:02X}")
    print()
    
    try:
        # Initialize I2C bus
        bus = SMBus(I2C_BUS)
        print("✅ I2C bus initialized")
        
        # Test connection by reading a byte
        try:
            data = bus.read_byte(ENCODER_ADDR)
            print(f"✅ Device responds at address 0x{ENCODER_ADDR:02X}")
            print(f"   First byte read: 0x{data:02X}")
            
            # Try to read encoder data
            try:
                encoder_data = bus.read_i2c_block_data(ENCODER_ADDR, 0x00, 16)
                print("✅ Successfully read 16 bytes of encoder data:")
                
                # Parse encoder values
                for i in range(8):
                    raw_value = (encoder_data[i*2] << 8) | encoder_data[i*2 + 1]
                    if raw_value > 32767:
                        raw_value -= 65536
                    print(f"   Encoder {i+1}: {raw_value}")
                
            except Exception as e:
                print(f"⚠️  Could not read encoder data: {e}")
            
            # Try to read button data
            try:
                button_data = bus.read_byte_data(ENCODER_ADDR, 0x10)
                print(f"✅ Button register: 0b{button_data:08b}")
                
                for i in range(8):
                    state = "PRESSED" if (button_data & (1 << i)) else "released"
                    print(f"   Button {i+1}: {state}")
                    
            except Exception as e:
                print(f"⚠️  Could not read button data: {e}")
                
        except Exception as e:
            print(f"❌ No device found at address 0x{ENCODER_ADDR:02X}: {e}")
            
            # Scan for other I2C devices
            print("\n🔍 Scanning for I2C devices...")
            devices_found = []
            for addr in range(0x03, 0x78):
                try:
                    bus.read_byte(addr)
                    devices_found.append(addr)
                except:
                    pass
            
            if devices_found:
                print("📱 Found devices at addresses:")
                for addr in devices_found:
                    print(f"   0x{addr:02X}")
            else:
                print("❌ No I2C devices found")
                print("\n🔧 Troubleshooting:")
                print("1. Check wiring connections")
                print("2. Verify I2C is enabled: sudo raspi-config")
                print("3. Check with i2cdetect: i2cdetect -y 1")
                
        bus.close()
        
    except Exception as e:
        print(f"❌ Failed to initialize I2C bus: {e}")
        print("\n🔧 Try:")
        print("1. sudo modprobe i2c-dev")
        print("2. Check /dev/i2c-1 exists")
        print("3. Add user to i2c group: sudo usermod -a -G i2c $USER")

if __name__ == "__main__":
    test_i2c_connection()
