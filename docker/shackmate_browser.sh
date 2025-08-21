#!/bin/bash
chromium-browser \
	--window-size=1024,600 \
	--kiosk \
	--incognito \
	--disable-infobars \
	--noerrdialogs \
	--disable-crash-report \
	--start-fullscreen \
	--start-maximized \
	--window-position=0,0 \
	--ignore-certificate-errors \
	--test-type \
	http://localhost
