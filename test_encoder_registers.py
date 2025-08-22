#!/usr/bin/env python3
"""
Mstack 8-Encoder Unit Register Test
Tests using the correct register map from encoder.h
"""

import time
import smbus2
import struct
import subprocess

# Register definitions from encoder.h
ENCODER_ADDR = 0x41
ENCODER_REG = 0x00
INCREMENT_REG = 0x20
BUTTON_REG = 0x50
SWITCH_REG = 0x60
RGB_LED_REG = 0x70
RESET_COUNTER_REG = 0x40
FIRMWARE_VERSION_REG = 0xFE
I2C_ADDRESS_REG = 0xFF

def check_device_present():
    """Check if device is present on I2C bus"""
    try:
        result = subprocess.run(['i2cdetect', '-y', '1'], 
                              capture_output=True, text=True, timeout=5)
        return '41' in result.stdout
    except:
        return False

def test_encoder_registers():
    """Test reading from the correct registers"""
    print("🔧 Testing Mstack 8-Encoder Unit with Correct Registers")
    print("=" * 60)
    
    # Check if device is present
    if not check_device_present():
        print("❌ Device not detected at 0x41")
        print("💡 Power cycle the encoder unit and run this script quickly!")
        return
    
    print("✅ Device detected at 0x41")
    
    bus = smbus2.SMBus(1)
    
    try:
        # Test 1: Read firmware version
        print("\n📋 Test 1: Firmware Version")
        print("-" * 30)
        try:
            version = bus.read_byte_data(ENCODER_ADDR, FIRMWARE_VERSION_REG)
            print(f"✅ Firmware version: {version}")
        except Exception as e:
            print(f"❌ Failed to read firmware version: {e}")
        
        # Test 2: Read I2C address register
        print("\n📋 Test 2: I2C Address Register")
        print("-" * 30)
        try:
            addr = bus.read_byte_data(ENCODER_ADDR, I2C_ADDRESS_REG)
            print(f"✅ I2C Address register: 0x{addr:02X}")
        except Exception as e:
            print(f"❌ Failed to read I2C address: {e}")
        
        # Test 3: Read switch status
        print("\n📋 Test 3: Switch Status")
        print("-" * 30)
        try:
            switch = bus.read_byte_data(ENCODER_ADDR, SWITCH_REG)
            print(f"✅ Switch status: 0x{switch:02X}")
        except Exception as e:
            print(f"❌ Failed to read switch status: {e}")
        
        # Test 4: Read button status
        print("\n📋 Test 4: Button Status (8 buttons)")
        print("-" * 30)
        try:
            buttons = bus.read_byte_data(ENCODER_ADDR, BUTTON_REG)
            print(f"✅ Button status: 0x{buttons:02X} (binary: {buttons:08b})")
            for i in range(8):
                status = "PRESSED" if (buttons & (1 << i)) else "RELEASED"
                print(f"   Button {i}: {status}")
        except Exception as e:
            print(f"❌ Failed to read button status: {e}")
        
        # Test 5: Read encoder values (each encoder is 4 bytes, signed 32-bit)
        print("\n📋 Test 5: Encoder Values (8 encoders)")
        print("-" * 30)
        
        for encoder_idx in range(8):
            try:
                # Each encoder value is 4 bytes starting at ENCODER_REG + (encoder_idx * 4)
                reg_addr = ENCODER_REG + (encoder_idx * 4)
                
                # Read 4 bytes for this encoder
                data = []
                for byte_offset in range(4):
                    byte_val = bus.read_byte_data(ENCODER_ADDR, reg_addr + byte_offset)
                    data.append(byte_val)
                
                # Convert 4 bytes to signed 32-bit integer (little-endian)
                encoder_value = struct.unpack('<i', bytes(data))[0]
                print(f"✅ Encoder {encoder_idx}: {encoder_value}")
                
            except Exception as e:
                print(f"❌ Failed to read encoder {encoder_idx}: {e}")
        
        # Test 6: Read increment values
        print("\n📋 Test 6: Increment Values (8 encoders)")
        print("-" * 30)
        
        for encoder_idx in range(8):
            try:
                # Each increment value is 4 bytes starting at INCREMENT_REG + (encoder_idx * 4)
                reg_addr = INCREMENT_REG + (encoder_idx * 4)
                
                # Read 4 bytes for this encoder
                data = []
                for byte_offset in range(4):
                    byte_val = bus.read_byte_data(ENCODER_ADDR, reg_addr + byte_offset)
                    data.append(byte_val)
                
                # Convert 4 bytes to signed 32-bit integer (little-endian)
                increment_value = struct.unpack('<i', bytes(data))[0]
                print(f"✅ Increment {encoder_idx}: {increment_value}")
                
            except Exception as e:
                print(f"❌ Failed to read increment {encoder_idx}: {e}")
        
        # Test 7: Try to set an LED color
        print("\n📋 Test 7: LED Control Test")
        print("-" * 30)
        try:
            # Try to set LED 0 to red (0xFF0000)
            # Each LED color is 3 bytes (RGB) starting at RGB_LED_REG + (led_idx * 3)
            led_reg = RGB_LED_REG + (0 * 3)  # LED 0
            
            # Write RGB values (Red = 0xFF, Green = 0x00, Blue = 0x00)
            bus.write_byte_data(ENCODER_ADDR, led_reg, 0xFF)     # Red
            bus.write_byte_data(ENCODER_ADDR, led_reg + 1, 0x00) # Green
            bus.write_byte_data(ENCODER_ADDR, led_reg + 2, 0x00) # Blue
            
            print("✅ LED 0 set to red - check if it lights up!")
            time.sleep(2)
            
            # Turn it off
            bus.write_byte_data(ENCODER_ADDR, led_reg, 0x00)     # Red
            bus.write_byte_data(ENCODER_ADDR, led_reg + 1, 0x00) # Green
            bus.write_byte_data(ENCODER_ADDR, led_reg + 2, 0x00) # Blue
            print("✅ LED 0 turned off")
            
        except Exception as e:
            print(f"❌ Failed to control LED: {e}")
    
    finally:
        bus.close()
    
    # Final device check
    if check_device_present():
        print("\n✅ Device still present after testing")
    else:
        print("\n❌ Device disappeared after testing")

def monitor_encoders():
    """Continuously monitor encoder changes"""
    print("\n🔄 Monitoring Encoder Changes")
    print("=" * 40)
    print("Turn encoders and press buttons to see changes!")
    print("Press Ctrl+C to stop")
    
    if not check_device_present():
        print("❌ Device not detected")
        return
    
    bus = smbus2.SMBus(1)
    
    # Store previous values
    prev_encoders = [0] * 8
    prev_buttons = 0
    
    try:
        while True:
            try:
                # Read all encoder values
                encoders = []
                for encoder_idx in range(8):
                    reg_addr = ENCODER_REG + (encoder_idx * 4)
                    data = []
                    for byte_offset in range(4):
                        byte_val = bus.read_byte_data(ENCODER_ADDR, reg_addr + byte_offset)
                        data.append(byte_val)
                    encoder_value = struct.unpack('<i', bytes(data))[0]
                    encoders.append(encoder_value)
                
                # Read button status
                buttons = bus.read_byte_data(ENCODER_ADDR, BUTTON_REG)
                
                # Check for changes
                encoder_changed = False
                for i in range(8):
                    if encoders[i] != prev_encoders[i]:
                        print(f"🔄 Encoder {i}: {prev_encoders[i]} → {encoders[i]} (Δ{encoders[i] - prev_encoders[i]})")
                        encoder_changed = True
                
                if buttons != prev_buttons:
                    print(f"🔘 Buttons: 0x{prev_buttons:02X} → 0x{buttons:02X}")
                    for i in range(8):
                        old_state = bool(prev_buttons & (1 << i))
                        new_state = bool(buttons & (1 << i))
                        if old_state != new_state:
                            state_str = "PRESSED" if new_state else "RELEASED"
                            print(f"   Button {i}: {state_str}")
                
                # Update previous values
                prev_encoders = encoders[:]
                prev_buttons = buttons
                
                time.sleep(0.1)  # 10Hz update rate
                
            except Exception as e:
                print(f"❌ Error reading data: {e}")
                break
                
    except KeyboardInterrupt:
        print("\n⏹️  Monitoring stopped")
    
    finally:
        bus.close()

if __name__ == "__main__":
    import sys
    
    if len(sys.argv) > 1 and sys.argv[1] == "--monitor":
        monitor_encoders()
    else:
        test_encoder_registers()
        print("\n💡 Run with --monitor to continuously watch for changes")
