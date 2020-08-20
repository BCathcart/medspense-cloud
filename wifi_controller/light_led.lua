-- Pulse the red LED
gpio.mode(3, gpio.OUTPUT)
gpio.write(3, gpio.LOW)
tmr.delay(1000000)   -- wait 1,000,000 us = 1 second
gpio.write(3, gpio.HIGH)
