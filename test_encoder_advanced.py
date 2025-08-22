#!/usr/bin/env python3
"""
Advanced Mstack 8-Encoder Unit Test
Tests different communication methods to find the correct protocol
"""

import sys
import time
try:
    from smbus2 import SMBus
except ImportError:
    print("❌ smbus2 not installed. Run: sudo pip3 install smbus2 --break-system-packages")
    sys.exit(1)

def test_communication_methods():
    """Test various I2C communication methods"""
    
    I2C_BUS = 1
    ENCODER_ADDR = 0x41
    
    print("🔍 Advanced Mstack 8-Encoder Communication Test")
    print("=" * 55)
    print(f"Device Address: 0x{ENCODER_ADDR:02X}")
    print()
    
    try:
        bus = SMBus(I2C_BUS)
        print("✅ I2C bus initialized")
        
        # Test 1: Try different read methods
        print("\n📋 Test 1: Basic Read Methods")
        print("-" * 30)
        
        methods = [
            ("read_byte", lambda: bus.read_byte(ENCODER_ADDR)),
            ("read_byte_data(0x00)", lambda: bus.read_byte_data(ENCODER_ADDR, 0x00)),
            ("read_byte_data(0x01)", lambda: bus.read_byte_data(ENCODER_ADDR, 0x01)),
            ("read_word_data(0x00)", lambda: bus.read_word_data(ENCODER_ADDR, 0x00)),
        ]
        
        for method_name, method_func in methods:
            try:
                result = method_func()
                print(f"✅ {method_name}: 0x{result:02X} ({result})")
            except Exception as e:
                print(f"❌ {method_name}: {e}")
        
        # Test 2: Try block reads with different lengths
        print("\n📋 Test 2: Block Read Methods")
        print("-" * 30)
        
        for length in [1, 2, 4, 8, 16, 32]:
            try:
                data = bus.read_i2c_block_data(ENCODER_ADDR, 0x00, length)
                print(f"✅ Block read {length} bytes: {[hex(x) for x in data[:8]]}")
                break  # If one works, we found the right length
            except Exception as e:
                print(f"❌ Block read {length} bytes: {e}")
        
        # Test 3: Try different register addresses
        print("\n📋 Test 3: Register Scanning")
        print("-" * 30)
        
        working_registers = []
        for reg in [0x00, 0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80]:
            try:
                data = bus.read_byte_data(ENCODER_ADDR, reg)
                print(f"✅ Register 0x{reg:02X}: 0x{data:02X} ({data})")
                working_registers.append(reg)
            except Exception as e:
                print(f"❌ Register 0x{reg:02X}: {e}")
        
        bus.close()
        
        print("\n📊 Summary:")
        if working_registers:
            print(f"✅ Working registers found: {[hex(r) for r in working_registers]}")
        else:
            print("❌ No working registers found - device might use different protocol")
        
    except Exception as e:
        print(f"❌ Failed to initialize I2C: {e}")

if __name__ == "__main__":
    test_communication_methods()
