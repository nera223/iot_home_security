import argparse
from bluepy.btle import *
import json
import urllib.request
import urllib.error
import pymysql


#Init argument parser
parser = argparse.ArgumentParser(description="Scan or connect to BLE devices. "
			"Input file CONNECT required for connect functionality.")

#argument '-s'
#	1. Triggers BLE scan
#	2. Analyzes advertising data to determine if the device is a securiotech one
#	3. If yes to (2), the MAC address is written to MySQL table 'scanned_macs'
parser.add_argument('-s', '--scan', help='Scan', action='store_true')

#argument '-c' attempts to connect
#	1. Fetches list of MAC addresses to try from MySQL table 'scanned_macs'
#	2. For each MAC address, attempts to create a Peripheral object (involves connecting)
#	3. If connection succeeds, a Delegate object is created for the device
#	4. Notification characteristics (0x2b AKA 43) are toggled for each to enable sensor notifications
#	5. Waits for notifications to roll in, which are handled by callbacks in the bluepy API (_getResp)
#		to handleNotification method of Delegate
#	6. ??? TODO
parser.add_argument('-c', '--connect', help='Connect. (can run with -s argument to scan and connect)', action='store_true')

args = parser.parse_args()

#Delegate class
#	Used to transfer data to/from BLE devices. Each device connection requires a Delegate instance.
class Delegate(DefaultDelegate):
		#Initialize with MAC address to help differentiate notifs from different peripherals
		def __init__(self, MAC):
			DefaultDelegate.__init__(self)
			self.MAC = MAC

		#Remembers whether advertising data is unique or a repeat detection
		def handleDiscovery(self, dev, isNewDev, isNewData):
			if isNewDev:
				print("Discovered device", dev.addr)
				#scanner.stop()
				#test = Peripheral(dev.addr, "public", 0)
				#print(test.getDescriptors(43,43)) # don't need just testing conn
				
				#test.disconnect()
				#scanner.clear()
				#scanner.start()
				#This is the jankiest thing possible
				print("it worked!")
				
				
			elif isNewData:
				print("Received new data from", dev.addr)

		#Called by bluepy whenever notification is received (asynchronous)
		#	Used to act on any and all data transmitted from peripherals
		def handleNotification(self, cHandle, data):
				#TODO code here to process handle data

				#Not yet ready
				# data = {"status" : 0 , "MAC" : "12.34.45..."}
				# data_json = json.dumps(data).encode('utf8')
				# headers = {'Content-type' : 'application/json'}
				# host = "http://0.0.0.0:3000/sensor"

				# req = urllib.request.Request(host, data=data_json, headers=headers)
				# response_stream = urllib.request.urlopen(req)
				# response = response_stream.read()

				# print(response)

				stdata = ' '
				for i in range(0, len(data)):
				        stdata = ' '.join((stdata, str(data[i])))
				print(self.MAC, ": ", cHandle, ": ", stdata)

if (args.scan):
	scanner = Scanner().withDelegate(Delegate(""))
	#devices = scanner.scan(5.0)
	scanner.clear()
	scanner.start()
	scanner.process(15)
	#scanner.stop()
	
	print("it actually works")
	
if (args.connect):

	#Collects MAC addresses within scanned_macs table
	db = pymysql.connect(host="localhost",user="iot", password="securiotech", db="system")
	c=db.cursor()
	c.execute("SELECT mac FROM scanned_macs")
	MAClist=c.fetchall()
	db.close()

	Sensors = []
	Characteristics = []
	j = 0;
	
	for i in range(len(MAClist)):
	
		try:
			print("Attempting connection to %s" % MAClist[i][0])
			
			#Connection is attempted during Peripheral object construction
			Sensors.append(Peripheral(MAClist[i][0], "public", 0))
			
			#References a Delegate object to the Peripheral
			Sensors[j].withDelegate(Delegate(MAClist[i][0]))
			
		#BTLEException is thrown if Peripheral constructor fails in connection
		except BTLEException:
			print("Could not find connection to %s. Verify device advertising or scan again." % MAClist[i][0])
			continue

		#Technically 43 (0x2b) is 'descriptor' on eval board.
		#Since nobody uses descriptors, API is janky with them. Must read as descriptor
		#	but write as a characteristic.
		#TODO: Make 'firmware' code in actual sensors so that notify toggle is char, not desc
		Characteristics.append(Sensors[j].getDescriptors(43, 43)[0])

		#Enable notifications on each Peripheral
		Sensors[j].writeCharacteristic(Characteristics[j].handle, (1).to_bytes(1, byteorder='big'), True)
		print("Connection to %s successful" % MAClist[i][0])
		j += 1

	while True:
	
		#Maybe find a better way to do this? I think this works always though
		#(yes even with multiple peripherals)
		if Sensors[0].waitForNotifications(1.0):
			#handleNotification() was called
			continue
		print("...")

