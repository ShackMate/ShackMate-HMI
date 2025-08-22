#!/usr/bin/env python3
"""
Mstack 8-Encoder Unit Wake-up and Initialization Test
Tests various wake-up sequences and initialization commands.
"""

import time
import smbus2
import subprocess
import sys

def run_i2cdetect():
    """Run i2cdetect to see if device is present"""
    try:
        result = subprocess.run(['i2cdetect', '-y', '1'], 
                              capture_output=True, text=True, timeout=5)
        lines = result.stdout.split('\n')
        for line in lines:
            if '40:' in line and '41' in line:
                return True
        return False
    except:
        return False

def test_wake_up_sequences():
    """Test various wake-up sequences"""
    print("🔍 Testing Wake-up Sequences for Mstack 8-Encoder Unit")
    print("=" * 60)
    
    # Check initial state
    print("\n📡 Initial I2C scan:")
    if run_i2cdetect():
        print("✅ Device 0x41 detected")
    else:
        print("❌ Device 0x41 NOT detected")
        print("💡 Power cycle the encoder unit and run this script quickly!")
        return
    
    bus = smbus2.SMBus(1)
    device_addr = 0x41
    
    # Test 1: Simple presence check
    print("\n📋 Test 1: Presence Check")
    print("-" * 30)
    try:
        # Try to read without sending any data first
        bus.read_byte(device_addr)
        print("✅ Device responds to simple read")
    except Exception as e:
        print(f"❌ Device doesn't respond to simple read: {e}")
    
    # Test 2: Common wake-up commands
    print("\n📋 Test 2: Common Wake-up Commands")
    print("-" * 30)
    
    wake_commands = [
        (0x00, "Null command"),
        (0xFF, "Reset command"),
        (0x01, "Start/Enable command"),
        (0xAA, "Wake-up pattern"),
        (0x55, "Sync pattern"),
        (0x10, "Init command"),
        (0x20, "Status request"),
    ]
    
    for cmd, desc in wake_commands:
        try:
            print(f"Trying {desc} (0x{cmd:02X})...")
            bus.write_byte(device_addr, cmd)
            time.sleep(0.1)  # Give device time to process
            
            # Try to read response
            try:
                response = bus.read_byte(device_addr)
                print(f"  ✅ Response: 0x{response:02X}")
            except:
                print(f"  ⏳ Command sent, no immediate response")
                
        except Exception as e:
            print(f"  ❌ Failed to send {desc}: {e}")
    
    # Test 3: Register-based initialization
    print("\n📋 Test 3: Register-based Initialization")
    print("-" * 30)
    
    init_sequences = [
        [(0x00, 0x01), "Enable at register 0x00"],
        [(0x01, 0x01), "Enable at register 0x01"],
        [(0x10, 0x01), "Control register init"],
        [(0x20, 0x01), "Mode register init"],
        [(0xFF, 0x00), "Reset sequence"],
        [(0x00, 0x00), (0x00, 0x01), "Reset then enable"],
    ]
    
    for sequence in init_sequences:
        if isinstance(sequence[0], tuple):
            # Multi-step sequence
            desc = sequence[-1]
            steps = sequence[:-1]
            print(f"Trying {desc}...")
            
            try:
                for reg, val in steps:
                    bus.write_byte_data(device_addr, reg, val)
                    time.sleep(0.05)
                print(f"  ✅ Sequence completed")
                
                # Try to read status
                try:
                    status = bus.read_byte_data(device_addr, 0x00)
                    print(f"  📊 Status register: 0x{status:02X}")
                except:
                    print(f"  ⏳ Cannot read status")
                    
            except Exception as e:
                print(f"  ❌ Sequence failed: {e}")
        else:
            # Single step
            reg, val = sequence[0]
            desc = sequence[1]
            print(f"Trying {desc}...")
            
            try:
                bus.write_byte_data(device_addr, reg, val)
                time.sleep(0.1)
                print(f"  ✅ Command sent")
                
                # Try to read back
                try:
                    readback = bus.read_byte_data(device_addr, reg)
                    print(f"  📊 Readback: 0x{readback:02X}")
                except:
                    print(f"  ⏳ Cannot read back")
                    
            except Exception as e:
                print(f"  ❌ Failed: {e}")
    
    # Test 4: Check if device is still present
    print("\n📋 Test 4: Post-test Device Check")
    print("-" * 30)
    
    if run_i2cdetect():
        print("✅ Device 0x41 still detected")
    else:
        print("❌ Device 0x41 disappeared - likely went to sleep")
    
    bus.close()

def test_continuous_communication():
    """Test keeping device awake with continuous communication"""
    print("\n🔄 Testing Continuous Communication")
    print("=" * 40)
    
    if not run_i2cdetect():
        print("❌ Device not detected. Power cycle and try again.")
        return
    
    bus = smbus2.SMBus(1)
    device_addr = 0x41
    
    print("Sending periodic commands to keep device awake...")
    print("Press Ctrl+C to stop")
    
    try:
        for i in range(30):  # 30 seconds of testing
            try:
                # Send a simple command every second
                bus.write_byte(device_addr, 0x00)
                time.sleep(0.1)
                
                # Try to read
                try:
                    data = bus.read_byte(device_addr)
                    print(f"[{i+1:2d}] ✅ Response: 0x{data:02X}")
                except:
                    print(f"[{i+1:2d}] ⏳ No response")
                
                time.sleep(0.9)  # Total 1 second interval
                
            except Exception as e:
                print(f"[{i+1:2d}] ❌ Error: {e}")
                break
                
    except KeyboardInterrupt:
        print("\n⏹️  Test stopped by user")
    
    # Final check
    if run_i2cdetect():
        print("✅ Device still present after continuous communication")
    else:
        print("❌ Device disappeared despite continuous communication")
    
    bus.close()

if __name__ == "__main__":
    print("🔧 Mstack 8-Encoder Unit Wake-up Test")
    print("=====================================")
    print()
    
    if len(sys.argv) > 1 and sys.argv[1] == "--continuous":
        test_continuous_communication()
    else:
        test_wake_up_sequences()
        print("\n💡 Tip: Run with --continuous to test keeping device awake")
    
    print("\n🏁 Test completed!")
