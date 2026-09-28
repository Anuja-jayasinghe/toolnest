#!/usr/bin/env python3
"""Move the mouse periodically to keep the computer active."""

import random
import time

import pyautogui


while True:
    x = random.randint(1600, 1700)
    y = random.randint(200, 600)
    pyautogui.moveTo(x, y, 0.5)
    time.sleep(3)
