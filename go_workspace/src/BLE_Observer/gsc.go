package main

import (

	g "github.com/currantlabs/gatt"
	"fmt"
	"bytes"
	json "encoding/json"
	bin "encoding/binary"
	http "net/http"
	r "runtime"

)

var jsonenabled bool = false

var url string

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

func onPeriphDiscovered(p g.Peripheral, a *g.Advertisement, r int) {
	//fmt.Printf("\nPeripheral ID:%s, NAME:(%s)\n", p.ID(), p.Name())
	//fmt.Println("  Local Name        =", a.LocalName)
	//fmt.Println("  TX Power Level    =", a.TxPowerLevel)
	//fmt.Println("  Manufacturer Data =", a.ManufacturerData)
	//fmt.Println("  Service Data      =", a.ServiceData)
	//fmt.Println("  RSSI              =", r, "\n")
 	if bytes.Equal(a.ManufacturerData, []byte{0xec, 0x9c, 0xd9, 0xc3, 0x2a, 0xed, 0xd0, 0x7f, 0x70, 0x61}){
		fmt.Println("Compatible device detected:", p.ID())
		p.Device().StopScanning()
		p.Device().Connect(p)
	} else {
		//fmt.Println("Incompatible device detected:", p.ID())
	}

}

func onPeriphConnected(p g.Peripheral, err error) {
	fmt.Println("Connected")
	
	//p.SetMTU(23)
	
	//pos documentation lies and claims to support UUID filtering. Source doesn't.
	fmt.Println("Discovering Services...")
	s, e := p.DiscoverServices(nil)
	if (e!=nil){
		fmt.Println("DiscoverServices Error: ", e)
	}
	
	//pos documentation lies and claims to support UUID filtering. Source doesn't.
	fmt.Println("Discovering Characteristics...")
	c, e := p.DiscoverCharacteristics(nil, s[3])
	if (e!=nil){
		fmt.Println("DiscoverCharacteristics Error: ", e)
	}

	fmt.Println("Reading Characteristic(s)...")
	v0, e := p.ReadCharacteristic(c[0])
	if (e!=nil){
		fmt.Println("ReadCharacteristic Error: ", e)
	}
	
	fmt.Println("Disconnecting...")
	p.Device().CancelConnection(p)
	
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
		fmt.Println(string([]byte(p.ID())))
		fmt.Println(string(message))
		url := "http://0.0.0.0:3000/sensor"
		req, e := http.NewRequest("POST", url, bytes.NewBuffer(message))
		if (e!=nil){
			fmt.Println("HTTP Request Formation Error: ", e)
		}
		req.Header.Set("Content-Type", "application/json")
		
		client := &http.Client{}
		//_ = client
		resp, e := client.Do(req)
		
		//memory leak solution. defer is amazing
		defer resp.Body.Close()
		
		if (e!=nil){
			fmt.Println("Client Response Error: ", e)
		}
		fmt.Println(resp)
		}

	
	}

func onPeriphDisconnected(p g.Peripheral, err error) {
	fmt.Println("Disconnected")
	p.Device().Scan([]g.UUID{}, true)
	return
}

func main() {
	
	//this device is the pi bluetooth "device" only
	dev, err := g.NewDevice()
	
	if (err != nil) {
		fmt.Printf("Error: %s\n",err)
		return
	} else {
		fmt.Printf("Device Created. \n")
	}
	
	//threads := r.NumCPU()
	desthreads := 2
	threads := r.GOMAXPROCS(desthreads)
	fmt.Println("Limiting to: ", desthreads, " threads from ", threads, " threads.")
	
	dev.Handle(
		g.PeripheralDiscovered(onPeriphDiscovered),
		g.PeripheralConnected(onPeriphConnected),
		g.PeripheralDisconnected(onPeriphDisconnected),
	)
	
	dev.Init(onStateChanged)

	//blocking function
	select{}
/* 	for{
		
		//this shows that it's possible to periodically (or conditionally) reset the device if it ever gives you trouble
		t.Sleep(10000 * t.Millisecond)
		fmt.Println("Hello there!")
	} */
}

