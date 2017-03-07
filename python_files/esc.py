#!/usr/bin/env python3


from gattlib import DiscoveryService
#from bluetooth import *

#service = DiscoveryService("hci0")

def callback(self, address, name, rssi, *args):
    # advertising data can contain more than just address and name, so passing the whole data array in args could be cool
    print("saw a device! ", address)

DiscoveryService.discover(callback)

# #subclassing DeviceDiscoverer and overriding a couple methods
# class Discovery(DeviceDiscoverer):

	# def __init__(self):
		# DeviceDiscoverer.__init__(self)

	# def device_discovered(self, address, device_class, name):
		# print("Discovered a Device: ", address)
		
		
# d = Discovery()

# d.find_devices(lookup_names=False)

#devices = service.discover(2)

#for address, name in devices.items():
#    print("name: {}, address: {}".format(name, address))