#!/usr/bin/env python3

import argparse
from bluepy.btle import *
import json
import urllib.request
import urllib.error
import pymysql


#Init argument parser
parser = argparse.ArgumentParser(description="Scan or connect to BLE devices. "
			"Input file CONNECT required for connect functionality.")

#Only one argument right now, but leaving argument parsing in case more are added. Will remove if not.

#argument '-s'
#	1. Triggers BLE scan
#	2. Analyzes advertising data to determine if the device is a securiotech one
#	3. If yes to (2), the MAC address is written to MySQL table 'scanned_macs'
parser.add_argument('-s', '--scan', help='Scan', action='store_true')

args = parser.parse_args()

#Delegate class
#	Used to transfer data to/from BLE devices. Each device connection requires a Delegate instance.
class Delegate(DefaultDelegate):
		#Initialize with MAC address to help differentiate notifs from different peripherals
		# TODO: MAC arg to be removed when finalized, design changed
		def __init__(self):
			DefaultDelegate.__init__(self)
			#self.MAC = MAC

		#Remembers whether advertising data is unique or a repeat detection
		def handleDiscovery(self, dev, isNewDev, isNewData):
			if isNewDev:
				print("Discovered device", dev.addr)
				#scanner.stop()
				try:
					scanner.stop()
				except BTLEException:
					print("scanner.stop threw a BTLEException, if you see this and code didn't crash- good")
					#this delay can bite, if the stars align and a remote device right as this unlucky thing happens
					#chances are should be very small though, especially with large process time.
					time.sleep(.5)
					scanner.stop()
				
				#probably don't need to loop through all adv data to retrieve this.. but it doesn't seem to matter
				for i in range(len(dev.getScanData())):
					if (dev.getScanData()[i][0] == 255) & (dev.getScanData()[i][2] == 'ec9cd9c32aedd07f7061'):
						#iscompatible = True
						Device = Peripheral(dev.addr, "public", 0)
						Data = Device.readCharacteristic(0x0020)
						#SensorStatus = Device.readCharacteristic(0x0012)
						#Voltage = Device.readCharacteristic(0x0017)
						#SensorType = Device.readCharacteristic(0x0003)
						
						Device.disconnect() #keep this line called ASAP
						
						#print(Data)
						
						#Format data (python array indexing is soo stupid)
						Mac = dev.addr
						SensorType = Data[0:4];
						SensorStatus = Data[4];
						Voltage = Data[5:7];
						
						#SensorStatus = int.from_bytes(SensorStatus, byteorder='little')
						Voltage = int.from_bytes(Voltage, byteorder='little')
						SensorType = SensorType.decode("utf-8")
						
						#form and send json req
						data = {"mac" : Mac , "type" : SensorType , "status" : SensorStatus , "battery" : Voltage}
						data_json = json.dumps(data).encode('utf8')
						headers = {'Content-type' : 'application/json'}
						host = "http://0.0.0.0:3000/sensor"
						req = urllib.request.Request(host, data=data_json, headers=headers)
						
						print("Compatible Device Interaction: ", Mac)
						print("Status: ", SensorStatus)
						print("Voltage: ", Voltage, " (mV)")
						print("Type: ", SensorType)
						try:
							response_stream = urllib.request.urlopen(req)
							response = response_stream.read()
							print("JSON Response: ", response.decode('utf-8'))
						except BadStatusLine:
							pass
						
						scanner.removeaddr(dev.addr)
						#scanner.clear()
					
				
				scanner.start()
				
				
				
				
				
			elif isNewData:
				print("Received new data from", dev.addr)

		#Called by bluepy whenever notification is received (asynchronous)
		#	Used to act on any and all data transmitted from peripherals
		def handleNotification(self, cHandle, data):

				pass
				# stdata = ' '
				# for i in range(0, len(data)):
				        # stdata = ' '.join((stdata, str(data[i])))
				# print(self.MAC, ": ", cHandle, ": ", stdata)

if (args.scan):
	scanner = Scanner().withDelegate(Delegate())
	while(1):
		#devices = scanner.scan(5.0)
		scanner.clear()
		scanner.start()
		scanner.process(1800)
		try:
			scanner.stop()
		except BTLEException:
			print("scanner.stop threw a BTLEException, if you see this and code didn't crash- good")
			#this delay can bite, if the stars align and a remote device right as this unlucky thing happens
			#chances are should be very small though, especially with large process time.
			time.sleep(.5)
			scanner.stop()
			
	

