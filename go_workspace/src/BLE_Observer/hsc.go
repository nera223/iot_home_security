/*
BLE Observer Script
Description: Runs at all times during system operation, scanning for BLE Advertisements
Upon matching manufacturer data to randomly generated 48 bit number, connects and reads
relevant data from device GATT, disconnects, and pushes formatted JSON request to thin server
on localhost.

Prerequisites: The RPi hci0 must at least be free before execution (ideally down already)

*/

package main

import (

	g "github.com/currantlabs/gatt"
	"fmt"
	"bytes"
	json "encoding/json"
	bin "encoding/binary"
	http "net/http"
	r "runtime"
	"os/exec"
)

//Toggle JSON requests, useful for debug
var jsonenabled bool = true

var url string

/*
Following functions create state machine for BLE communication
*/
/*
Called whenever a 'device' used to handle all HCI actions changes state
Only being used to initialize the device and restart it if it goes down
*/
func onStateChanged(d g.Device, s g.State) {
	fmt.Println("State:", s)
	switch s {
		case g.StatePoweredOn:
			fmt.Println("scanning...")
			d.Scan([]g.UUID{}, true)
			return
		default:
			d.StopScanning()
			fmt.Println("Device state changed unexpectedly, attempting reinit...")
			d.Init(onStateChanged)
	}
}

/*
Whenever a peripheral is discovered, this function is called.
Description: Analyzes manufacturing data and connects on match
*/
func onPeriphDiscovered(p g.Peripheral, a *g.Advertisement, r int) {
	//fmt.Printf("\nPeripheral ID:%s, NAME:(%s)\n", p.ID(), p.Name())
	//fmt.Println("  Local Name        =", a.LocalName)
	//fmt.Println("  TX Power Level    =", a.TxPowerLevel)
	//fmt.Println("  Manufacturer Data =", a.ManufacturerData)
 	if bytes.Equal(a.ManufacturerData, []byte{0xec, 0x9c, 0xd9, 0xc3, 0x2a, 0xed}){ //0xd0, 0x7f, 0x70, 0x61}){
		fmt.Println("Compatible device detected:", p.ID())
		fmt.Println("  RSSI              =", r, "\n")
		p.Device().StopScanning()
		p.Device().Connect(p)
	} else {
		//fmt.Println("Incompatible device detected:", p.ID())
	}
	//fmt.Println("  Service Data      =", a.ServiceData)
	
}


/*
Whenever a peripheral is connected, this function is called.
Description: Once a connection is formed, asks the peripheral GATT server for all services,
	characteristics. It isn't optimal, but without the API supporting UUID/handle filtering
	the extra work involved to implement it wouldn't be worthwhile. Once the data is gathered
	from the services of interest, the connection is severed and JSON request sent.
*/
func onPeriphConnected(p g.Peripheral, err error) {
	fmt.Println("Connected")
	
	//MTU of PSoC by default is 23, experimented with adjustments but observed no significant change
	//Without explicitly setting it here, the MTU is set to 23 by default
	//p.SetMTU(46)
	
	//documentation lies and claims to support UUID filtering. Source doesn't.
	fmt.Println("Discovering Services...")
	s, e := p.DiscoverServices(nil)
	if (e!=nil){
		fmt.Println("DiscoverServices Error: ", e)
	}
	
	//documentation lies and claims to support UUID filtering. Source doesn't.
	fmt.Println("Discovering Characteristics...")
	c, e := p.DiscoverCharacteristics(nil, s[len(s)-1])
	if (e!=nil){
		fmt.Println("DiscoverCharacteristics Error: ", e)
	}
	
	fmt.Println("Reading Characteristic(s)...")
	v0, e := p.ReadCharacteristic(c[0])
	if (e!=nil){
		fmt.Println("ReadCharacteristic Error: ", e)
	}
	
	//Disconnect as soon as possible
	fmt.Println("Disconnecting...")
	p.Device().CancelConnection(p)
	
	//Form JSON Request
	if (jsonenabled) {
		
		//note vars must be capitalized to avoid problems (i'm not even kidding)
		type Message struct {
			Mac string		`json:"mac"`
			SType string	`json:"type"`
			Status byte		`json:"status"`
			Battery uint16	`json:"battery"`
		}
		
		fmt.Println(bin.LittleEndian.Uint16(v0[5:7]));
		m := Message{p.ID(), string(v0[0:4]), v0[4], bin.LittleEndian.Uint16(v0[5:7])}
		
		message, e := json.Marshal(m)
		if (e != nil){
			fmt.Println("JSON Marshal Error: ", e)
		}

		fmt.Println(string(message))
		
		//URL is that of application server, which is localhost
		url := "http://0.0.0.0:3000/sensor"
		req, e := http.NewRequest("POST", url, bytes.NewBuffer(message))
		if (e!=nil){
			fmt.Println("HTTP Request Formation Error: ", e)
		}
		req.Header.Set("Content-Type", "application/json")

		client := &http.Client{}

		resp, e := client.Do(req)
		
		if (e!=nil){
			fmt.Println("Client Response Error: ", e)
			return
		}
		
		//memory leak solution
		defer resp.Body.Close()
		
		//fmt.Println(resp)
		
		}
	
	}

/*
Called on peripheral disconnect
Description: Restarts the scanner on disconnect. Due to multithreading, this can execute
	while the JSON request of the previous communication is finished being sent. This is why
	we disconnect as soon as possible in the onConnected handler.
*/
func onPeriphDisconnected(p g.Peripheral, err error) {
	fmt.Println("Disconnected")
	if (err!=nil){fmt.Printf("Error: %s\n",err)}
	p.Device().Scan([]g.UUID{}, true)
	return
}

func main() {

	//attempt to bring hci0 down, it is required to be down to use this API
	//if the hci0 is in use, this command will not execute and script will crash
	//when attempting to create device
	out, erro := exec.Command("sudo", "hciconfig", "hci0", "down").Output()
	_ = out; //Golang requires all variables to be used.
	
	if erro != nil {
		fmt.Printf("Error: %s\n",erro)
		return
	}
		

	//this device is the pi bluetooth "device" only
	//dev, err := g.NewDevice(g.LnxSetAdvertisingParameters(&cmd.LESetAdvertisingParameters{AdvertisingIntervalMin:0x800}))
	dev, err := g.NewDevice()
	
	if (err != nil) {
		fmt.Printf("Error: %s\n",err)
		return
	} else {
		fmt.Printf("Device Created. \n")
	}
	
	threads := r.NumCPU();
	desthreads := 2
	
	//Throttles execution to 2 threads, leaving the other 2 free for camera or other cpu intensive tasks
	threads = r.GOMAXPROCS(desthreads)
	fmt.Println("Limiting to: ", desthreads, " threads from ", threads, " threads.")
	
	//declares handler functions
	dev.Handle(
		g.PeripheralDiscovered(onPeriphDiscovered),
		g.PeripheralConnected(onPeriphConnected),
		g.PeripheralDisconnected(onPeriphDisconnected),
	)
	
	//starts the device and enters the state machine
	dev.Init(onStateChanged)


	//blocking
	//using select{} doesn't hog a whole core like for{} does
	//for{}
	select{}
}
