#!/bin/bash

# Commit and push the encoder fixes with proper register map

echo "🔧 Committing encoder register map fixes..."

# Add all new files
git add test_encoder_registers.py test_encoder_wakeup.py

# Add modified files
git add encoder_reader.py

# Commit
git commit -m "Fix encoder communication with correct register map

- Add proper register definitions from encoder.h
- Update encoder_reader.py to use correct I2C registers
- Add comprehensive register testing script
- Add wake-up sequence testing script
- Fix encoder values to be 32-bit signed integers
- Fix button register address (0x50)
- Add firmware version detection"

# Push
git push origin main

echo "✅ Changes committed and pushed!"
