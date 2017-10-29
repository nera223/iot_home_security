/* 
    Insert clever header
*/
#include <project.h>
#include <stdio.h>

/* WDT counter configuration */
/* Sets less significant WDT to iterate more significant every 1 second */
#define WDT_COUNT0_MATCH    (0x8000u)

/* # here represents seconds for more significant WDT to interupt */
#define WDT_COUNT1_MATCH    (0x0005u)

//Defines adc channel 0 id, don't really need
#define CH0_N               (0x00u)
#define CH1_N               (0x01u)

//max number of samples between transmits
#define TX_Interval         (1u)

//needs more work to define and find optimal settings
//one things for sure the installation under the psoc board is unacceptable
#define Smk_Thresh          (0u)

#define DOUT_ON             (0u)
#define DOUT_OFF            (1u)


//uint8 GPIO3flag = 0u;
uint8 WDTflag = 0u;

uint16 VDDIO = 0;
uint32 Smk = 0;

/* Prototype of WDT ISR */
CY_ISR_PROTO(WdtIsrHandler);

/*BLE Stack handler prototypes*/
void StackEventHandler(uint32 event, void *eventParam);

/* Fn Prototypes */
void WDTInit(uint, uint);
void I2CInit();
uint32 SmkWrite(uint8 Reg, uint8 Data);
uint8 SmkRead(uint8 Reg);
void SmkInit();
uint32 SmkPoll();
int16 BatPoll();
void COInit();
uint32 COPoll();
uint8 SampCount = 0;

CYBLE_BLESS_STATE_T blessState;
CYBLE_GATT_HANDLE_VALUE_PAIR_T HVPair;

#define CUST_DATA_LEN       (8u)
uint8 CustData[CUST_DATA_LEN] = {'s', 'm', 'c', 'o'};
#define STATUS_INDEX        (4u)
#define BATTERY_INDEX       (5u)


/*******************************************************************************
* Function Name: main
********************************************************************************

    Summary:
    1. Initializes program. 
    2. Enters sleep mode, awaiting interrupt source. 
    3. Sleep called within infinite loop.
    4. Upon interrupt, loop resumes and rest of loop executes.
    5. Further interrupts are disabled and the interrupt source
        is evaluated from flags.
    6. TODO: everything else

    Parameters:
    None

    Return:
    None

*******************************************************************************/
int main()
{   
    
    CYBLE_API_RESULT_T apiResult;
    //Start BLE Stack, set handler
    apiResult = CyBle_Start(StackEventHandler);
    
    if(apiResult != CYBLE_ERROR_OK)
    {
        /* BLE stack initialization failed, check your configuration */
        CYASSERT(0);
    }

    //initialize components
    //Starts ADC
    ADC_SAR_Seq_Start();
    
    I2CInit();
    
    //Powers Smoke Circuitry
    SmkInit();
    
    /* 32768 for one second T on count0, num seconds as count1 */
    WDTInit(WDT_COUNT0_MATCH, WDT_COUNT1_MATCH);
    
    cyBle_eventHandlerFlag = CYBLE_ENABLE_ALL_EVENTS;
    
	for(;;)
    {
        //uint8 intrStatus;
        //count1 = 0u;
        
        
        /* explicitly resetting WDTs here just to avoid back-to-back interrupts on GPIO ints */
        CySysWdtResetCounters(CY_SYS_WDT_COUNTER0_RESET|CY_SYS_WDT_COUNTER1_RESET);
        //I2C_1_Start();
        
        ADC_SAR_Seq_Wakeup();

        if (1u == WDTflag)
        {
            SampCount += 1u;
            WDTflag = 0u;
        }
        
        Smk = SmkPoll();
        
        
        if (Smk > Smk_Thresh || SampCount >= TX_Interval){
            CyBle_ExitLPM();
            
            SampCount = 0;
            
            HVPair.attrHandle = 0x0012;
            
            //testing only
            VDDIO = Smk;//BatPoll();
            
            CustData[BATTERY_INDEX] = VDDIO & 0x00ff;
            CustData[BATTERY_INDEX+1] = (VDDIO & 0xff00) >> 8;
            
            if (Smk > Smk_Thresh){
                CustData[STATUS_INDEX] = 1u;
            }else{
                CustData[STATUS_INDEX] = 0u;   
            }
            
            //Data construction complete, place into Handle-Value pair struct
            HVPair.value.val = CustData;
            HVPair.value.len = CUST_DATA_LEN;
            //UART_PutString("Writing to GATT..");
            CyBle_GattsWriteAttributeValue(&HVPair, 0u, 0u, CYBLE_GATT_DB_LOCALLY_INITIATED);
            
            //must be in state 4 / disconnected to call this:
            CyBle_GappStartAdvertisement(CYBLE_ADVERTISING_FAST);
            
                
        }
        //Hijacking battery indices to see smk sample data for testing
        //CustData[BATTERY_INDEX] = Smk & 0x0000ff;
        //CustData[BATTERY_INDEX+1] = (Smk & 0x00ff00) >> 8;
        //CustData[BATTERY_INDEX+2] = (Smk & 0xff0000) >> 16;
        

        /* Get the current state of BLESS block */
        blessState = 0u;
        /* If BLESS is in Deep-Sleep mode or the XTAL oscillator is turning on,
        then PSoC 4 BLE can enter Deep-Sleep mode (1.3uA current consumption)
        once the while is broken*/
        while (blessState != CYBLE_BLESS_STATE_ECO_ON && blessState != CYBLE_BLESS_STATE_DEEPSLEEP)
        //while (blessState != CYBLE_BLESS_STATE_DEEPSLEEP)
        {
            blessState = CyBle_GetBleSsState();
            //CyBle_EnterLPM(CYBLE_BLESS_DEEPSLEEP);
            CyBle_ProcessEvents();
        }
        


        CySysPmDeepSleep();
        
        //CyExitCriticalSection(intrStatus);

        //CyBle_SoftReset();

    }
}

void StackEventHandler(uint32 event, void *eventParam)
{
    //char  uartLine[250];

    switch(event)
    {
        /* BLE stack events get handled here */   
        case CYBLE_EVT_STACK_ON:

            CyBle_EnterLPM(CYBLE_BLESS_DEEPSLEEP);

            break;

        case CYBLE_EVT_GAP_DEVICE_DISCONNECTED:

            CyBle_EnterLPM(CYBLE_BLESS_DEEPSLEEP);

            break;
        
        
        case CYBLE_EVT_GAP_DEVICE_CONNECTED:
            
            break;

        case CYBLE_EVT_GAPP_ADVERTISEMENT_START_STOP:
            CySysWdtResetCounters(CY_SYS_WDT_COUNTER0_RESET|CY_SYS_WDT_COUNTER1_RESET);
            
            if(CyBle_GetState() == CYBLE_STATE_DISCONNECTED)
            {
                //UART_PutString("Failed to connect, changing state to disconnected \n \r");
                CyBle_EnterLPM(CYBLE_BLESS_DEEPSLEEP);
                
            }
            else if (CyBle_GetState() == CYBLE_STATE_ADVERTISING)
            {

            }
            
            
            break;
            
        case CYBLE_EVT_GATTS_READ_CHAR_VAL_ACCESS_REQ:
            
            break;
            
        default:
            break;
    }
}


/*******************************************************************************
* Function Name: WdtIsrHandler
********************************************************************************

    Summary:
    1. Callback target upon WDT interrupt.
    2. Clears interrupt on hardware and software level.
    3. Sets WDTflag and code continues execution after deepsleep cmd in main.

    Parameters:
    None

    Return:
    None

*******************************************************************************/
CY_ISR(WdtIsrHandler)
{
	/* Toggle pin state */
	//LED_Blue_Write(~(LED_Blue_Read()));

    /* Clear interrupts state */
	CySysWdtClearInterrupt(CY_SYS_WDT_COUNTER1_INT);
    WdtIsr_ClearPending();
    //UART_PutString("Interrupted by WDT \n \r");
    
    WDTflag = 1u;

}


/*******************************************************************************
* Function Name: WDTInit
********************************************************************************
note this is a fairly inaccurate timer, +/- 5% at least. maybe configurable (weird)

Summary:
    1. Disables WDT 0 and 1 just in case
    2. Starts interrupt server routine and enables HW interrupts.
    3. Initializes WDT0 as non-interrupting LSB counter with match every Match0/32768 s
    4. Sets up cascade with WDT1, which receives matches from WDT0
    5. Configure WDT1 as interrupting with match every Match1 s
    6. Enable counters and return.
    

Parameters:
    1. Match0 - unsigned int value for which WDT0 outputs a pulse and is reset.
        32768, 0x4FFF provides a handy 1s period. can go up to 2^16-1 = 65535 ~2s
    2. Match1 - unsigned int value for which WDT1 issues an interrupt. Interrupt
        occurs every T0*Match1 seconds, or in standard case every Match1 seconds.
        Can be configured up to 2^16-1 for max total WDT timer of 2s*65535 = 36hrs.

Return:
    None

*******************************************************************************/
void WDTInit(uint Match0, uint Match1)
{
    CySysWdtDisable(CY_SYS_WDT_COUNTER0_MASK | CY_SYS_WDT_COUNTER1_MASK);
    CySysWdtResetCounters(CY_SYS_WDT_COUNTER0_RESET|CY_SYS_WDT_COUNTER1_RESET);
    
    WdtIsr_StartEx(WdtIsrHandler);
    CyGlobalIntEnable;
    
    /* Set WDT counter 0 to count (32.768kHz, match value 32768- can adjust) */
	CySysWdtSetMode(CY_SYS_WDT_COUNTER0, CY_SYS_WDT_MODE_NONE);
	CySysWdtSetMatch(CY_SYS_WDT_COUNTER0, Match0);
	CySysWdtSetClearOnMatch(CY_SYS_WDT_COUNTER0, 1u);
    
    /* Enable WDT counters 0 and 1 cascade */
	CySysWdtSetCascade(CY_SYS_WDT_CASCADE_01);
    
    /* Set WDT counter 1 to generate interrupt on match */
    /* can modify to be reset (reinitializes all, more t, more p) */
    CySysWdtSetMode(CY_SYS_WDT_COUNTER1, CY_SYS_WDT_MODE_INT);
	CySysWdtSetMatch(CY_SYS_WDT_COUNTER1, Match1);
    CySysWdtSetClearOnMatch(CY_SYS_WDT_COUNTER1, 1u);
    
    /* Enable WDT counters 0 and 1 */
    /*could also add counter 2 into the mix if we want to sleep for up to 
    2*2^16*2^32 = 562949953421312 seconds = 17.8 million years lol*/
	CySysWdtEnable(CY_SYS_WDT_COUNTER0_MASK | CY_SYS_WDT_COUNTER1_MASK);
    
    //UART_PutString("WDT Initialized \n \r");
    
}

/*******************************************************************************
* Function Name: I2C Init
********************************************************************************

Summary:
    1. Initializes I2C Subsystem

Parameters:
    None

Return:
    None

*******************************************************************************/
void I2CInit()
{
    I2C_1_Start();   
}


/*******************************************************************************
* Function Name: SmkWrite
********************************************************************************

Summary:
    1. Writes a to a register onboard the smoke detector chip using base I2C

Parameters:
    register address
    data to write

Return:
    None

*******************************************************************************/
uint32 SmkWrite(uint8 Reg, uint8 Data)
{
    uint32 err = 1u;
    
    //Using Stop universally in write/read should not cause problems with one slave
    
    while(err != 0){
        err = I2C_1_I2CMasterSendStart(87u, I2C_1_I2C_WRITE_XFER_MODE);
    }
    I2C_1_I2CMasterWriteByte(Reg);

    I2C_1_I2CMasterWriteByte(Data);

    I2C_1_I2CMasterSendStop();

    
    return err;
}

/*******************************************************************************
* Function Name: SmkRead
********************************************************************************

Summary:
    1. REads a to a register onboard the smoke detector chip using base I2C

Parameters:
    register address

Return:
    Data contained within specified register

*******************************************************************************/
uint8 SmkRead(uint8 Reg)
{

    uint8 data;
    
    I2C_1_I2CMasterSendStart(87u, I2C_1_I2C_WRITE_XFER_MODE);

    I2C_1_I2CMasterWriteByte(Reg);

    I2C_1_I2CMasterSendRestart(87u, I2C_1_I2C_READ_XFER_MODE);
    
    data = I2C_1_I2CMasterReadByte(I2C_1_I2C_ACK_DATA);
    I2C_1_I2CMasterSendStop();
    return data;
}

/*******************************************************************************
* Function Name: SmkInit
********************************************************************************

Summary:
    1. Initializes Smk Sensor by writing data to configuration registers and
        clearing interrupts as necessary on the smoke chip.

    2. Not the best documented function, but refer to datasheet for registers

Parameters:
    none

Return:
    none

*******************************************************************************/
void SmkInit()
{
    //supply power
    Pin_1_Write(1u);
    CyDelay(1u);
    
    //read int1 register to clear pwr-rdy interrupt
    SmkRead(0x00);
    
    //Initiate POR to be safe, uneasy with just applying voltage
    SmkWrite(0x09, 0x40);
    CyDelay(1u);
    
    //Write to config registers:
    //Important information:
    //800 sps, using red and IR led
    //averaging 8 samples per sample
    //must refer to MAXIM chip datasheet for details
    SmkWrite(0x08, 0x70);
    SmkWrite(0x09, 0x02);
    SmkWrite(0x0A, 0x51);
    SmkWrite(0x0C, 0x0F);
    SmkWrite(0x0D, 0x0F);
    SmkWrite(0x0E, 0x0F);
    SmkWrite(0x11, 0x21);
    SmkWrite(0x12, 0x00);
    
    //Shut down component
    //samples stop, still responsive to I2C commands, ~1uA state
    SmkWrite(0x09, 0x82);
    
}


/*******************************************************************************
* Function Name: SmkPoll
********************************************************************************

Summary:
    1. Wakes the chip from sleep
    2. Sets FIFO data read/write pointers to 0 to overwrite old data
    3. Wait for a sample to complete and populate FIFO
    4. Read data as appropriate
    5. Put chip back to sleep
    6. Return measurement

Parameters:
    none

Return:
    smoke sample

*******************************************************************************/
uint32 SmkPoll()
{
    uint32 RedSamp = 0u;
    uint32 IRSamp = 0u;
    
    //Leave shutdown state, begin sample acquisition
    SmkWrite(0x09, 0x02);

    CyDelay(1u);
    
    //Clear FIFO r/w pointers
    //Begins writing FIFO from 0 regardless of stale data present
    SmkWrite(0x04, 0x00);
    SmkWrite(0x06, 0x00);
    

    
    //Sampling 800sps, averaging 8 samples per FIFO entry
    //Delay 11ms should ensure that one FIFO sample completes
    CyDelay(11u);
    
    //Using SmkRead Fn here is inefficient since it's done so often
//    RedSamp += SmkRead(0x07)<<16; //For our case this should always be 0
//    RedSamp += SmkRead(0x07)<<8;
//    RedSamp += SmkRead(0x07);
//    
//    IRSamp += SmkRead(0x07)<<16; //For our case this should always be 0
//    IRSamp += SmkRead(0x07)<<8;
//    IRSamp += SmkRead(0x07);

    //All we have to retrieve is one sample stored in 6B
    //and rebuild sample results
    I2C_1_I2CMasterSendStart(87u, I2C_1_I2C_WRITE_XFER_MODE);
    I2C_1_I2CMasterWriteByte(0x07);
    I2C_1_I2CMasterSendRestart(87u, I2C_1_I2C_READ_XFER_MODE);
    RedSamp += I2C_1_I2CMasterReadByte(I2C_1_I2C_ACK_DATA)<<16;
    RedSamp += I2C_1_I2CMasterReadByte(I2C_1_I2C_ACK_DATA)<<8;
    RedSamp += I2C_1_I2CMasterReadByte(I2C_1_I2C_ACK_DATA);
    IRSamp  += I2C_1_I2CMasterReadByte(I2C_1_I2C_ACK_DATA)<<16;
    IRSamp  += I2C_1_I2CMasterReadByte(I2C_1_I2C_ACK_DATA)<<8;
    IRSamp  += I2C_1_I2CMasterReadByte(I2C_1_I2C_ACK_DATA);
    I2C_1_I2CMasterSendStop();
    
    //Return to sleep
    SmkWrite(0x09, 0x82);
    
    return RedSamp; //just returning red samp for now
    
}

/*******************************************************************************
* Function Name: BatPoll()
********************************************************************************

Summary:
    1. Wakes ADC
    2. Adjusts circuit using GPIO to put voltage being measured on ADC input pin
    3. After electrical settling, ADC conversion started
    4. Converted sloppily back to base volts (ADC uses divider and 1.024 Vref)
    5. Stops current flow and puts ADC subsystem to sleep
    6. Returns sample

Parameters:
    none

Return:
    Battery voltage sample

*******************************************************************************/
int16 BatPoll()
{
    int16 output;
    uint32 vnode;
    /* Wakeup requires some start time that isn't inherently handled
    It's definitely relative from testing. Think it's ~1 to 1.5 conversion sequence times
    just leaving 1ms for now, can tweak to clock cycles if needed*/

    ADC_SAR_Seq_Wakeup();
    
    Pin_3_Write(0u);
    
    CyDelay(1u);
    
    ADC_SAR_Seq_StartConvert();
    ADC_SAR_Seq_IsEndConversion(ADC_SAR_Seq_WAIT_FOR_RESULT);
    
    //*5u is volt. divider correction factor approximately equal to (6.8+27)/6.8
    vnode = ADC_SAR_Seq_GetResult16(CH0_N) * 4.9706;
    Pin_3_Write(1u);
    output = ADC_SAR_Seq_CountsTo_mVolts(CH0_N, vnode) + 285;
    ADC_SAR_Seq_Sleep();
    
    return output;
}

void COInit()
{
    //Choosing to leave on always, should be less than 500nA
    Pin_4_Write(1u);   
}

uint32 COPoll()
{
    uint32 output;
    ADC_SAR_Seq_Wakeup();
    
    ADC_SAR_Seq_StartConvert();
    ADC_SAR_Seq_IsEndConversion(ADC_SAR_Seq_WAIT_FOR_RESULT);
    
    output = ADC_SAR_Seq_GetResult16(CH1_N);
    
    ADC_SAR_Seq_Sleep();
    
    return output;
}

/* [] END OF FILE */
