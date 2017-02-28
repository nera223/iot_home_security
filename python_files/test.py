from time import sleep
import serial

# Establish the connection on a specific port
ser = serial.Serial('/dev/bus/usb/001/007', 115200) 

#x = 1
while True:
       ser.readline() # Read the newest output 
       #x += 1
