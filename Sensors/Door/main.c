/* 
    Insert clever header
*/
#include <project.h>
#include <stdio.h>

/* WDT counter configuration */
/* Sets less significant WDT to iterate more significant every 1 second */
#define WDT_COUNT0_MATCH    (0x8000u)

/* # here represents seconds for more significant WDT to interupt */
#define WDT_COUNT1_MATCH    (0x000Fu)

#define CH0_N               (0x00u)

/* Var Declarations */
uint8 GPIO1flag = 0u;           
uint8 GPIO2flag = 0u;
uint8 WDTflag = 0u;
uint8 DOOR_OPEN = 1u;
uint8 DOOR_SHUT = 0u;

uint16 VDDIO = 0;

/* Prototype of WDT ISR */
CY_ISR_PROTO(WdtIsrHandler);
CY_ISR_PROTO(GPIO1_isrHandler);
CY_ISR_PROTO(GPIO2_isrHandler);

/*BLE Stack handler prototypes*/
void StackEventHandler(uint32 event, void *eventParam);

/* Fn Prototypes */
void WDTInit(uint, uint);
void GPIOIntInit();
void EnableAllIsr(uint8);

int16 PollADC();

CYBLE_BLESS_STATE_T blessState;
CYBLE_GATT_HANDLE_VALUE_PAIR_T HVPair;

#define CUST_DATA_LEN       (7u)
uint8 CustData[CUST_DATA_LEN] = {'d', 'o', 'o', 'r'};
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
    
    //registers GPIO ISRs
    GPIOIntInit();
    //Starts ADC
    ADC_SAR_Seq_Start();
    
    /* 32768 for one second T on count0, num seconds as count1 */
    WDTInit(WDT_COUNT0_MATCH, WDT_COUNT1_MATCH);
    
    cyBle_eventHandlerFlag = CYBLE_ENABLE_ALL_EVENTS;
    
	for(;;)
    {

        /* explicitly resetting WDTs here just to avoid back-to-back interrupts on GPIO ints */
        CySysWdtResetCounters(CY_SYS_WDT_COUNTER0_RESET|CY_SYS_WDT_COUNTER1_RESET);
        
        /* taking a time-out from all interrupts. TODO: Add priority tiers and remove
            don't want a door open signal failing to interrupt a WDT routine*/
        EnableAllIsr(0u);
        HVPair.attrHandle = 0x0012;

        if (1u == WDTflag)
        {
            WDTflag = 0u;
        }
        else if (1u == GPIO1flag)
        {
            //status 1 indicates door opened
            CustData[STATUS_INDEX] = 0x01;
            
            //Swap door switch voltages
            Pin_1_Write(0u);
            Pin_2_Write(1u);
        
            GPIO1flag = 0u;
        }
        else if (1u == GPIO2flag)
        {
            //status 0 indicates door closed
            CustData[STATUS_INDEX] = 0x00;
            
            //Swap door switch voltages
            Pin_1_Write(1u);
            Pin_2_Write(0u);
            
            GPIO2flag = 0u;
        }
        else
        {
            //only else during initialization
        }
        
        VDDIO = PollADC();
        
        CustData[BATTERY_INDEX] = VDDIO & 0x00ff;
        CustData[BATTERY_INDEX+1] = (VDDIO & 0xff00) >> 8;
        
        //Data construction complete, place into Handle-Value pair struct
        HVPair.value.val = CustData;
        HVPair.value.len = CUST_DATA_LEN;
        //writing to GATT
        CyBle_GattsWriteAttributeValue(&HVPair, 0u, 0u, CYBLE_GATT_DB_LOCALLY_INITIATED);

        //must be in state 4 / disconnected to call this:
        CyBle_GappStartAdvertisement(CYBLE_ADVERTISING_FAST);
        
        /* Get the current state of BLESS block */
        /* If BLESS is in Deep-Sleep mode or the XTAL oscillator is turning on,
        then PSoC 4 BLE can enter Deep-Sleep mode (1.3uA current consumption)
        once the while is broken*/
        blessState = 0u;
        while (blessState != CYBLE_BLESS_STATE_ECO_ON && blessState != CYBLE_BLESS_STATE_DEEPSLEEP)
        {
            blessState = CyBle_GetBleSsState();
            CyBle_ProcessEvents();
        }
        
        EnableAllIsr(1u);
        
        
        //entering deep sleep
        CySysPmDeepSleep();
        
        //waking up (code resumes here)
        CyBle_ExitLPM();

    }
}

void StackEventHandler(uint32 event, void *eventParam)
{

    switch(event)
    {
        /* BLE stack events get handled here */   
        case CYBLE_EVT_STACK_ON:

            CyBle_EnterLPM(CYBLE_BLESS_DEEPSLEEP);

            break;
            
        //  This is the EVENT device disconnected, as opposed to the STATE disconnected.
        //  only occurs when a connected device disconnected, not every time the disconnect state is entered.
        case CYBLE_EVT_GAP_DEVICE_DISCONNECTED:
            
            //After device DC, want to put BLE system in low power
            CyBle_EnterLPM(CYBLE_BLESS_DEEPSLEEP);

            break;
        
        
        case CYBLE_EVT_GAP_DEVICE_CONNECTED:
            //do nothing
            //LED_Green_write(0u);
            
            break;

        case CYBLE_EVT_GAPP_ADVERTISEMENT_START_STOP:
            //Reset WDT in either case (not needed for long cycle)
            CySysWdtResetCounters(CY_SYS_WDT_COUNTER0_RESET|CY_SYS_WDT_COUNTER1_RESET);
            
            if(CyBle_GetState() == CYBLE_STATE_DISCONNECTED)
            {
                //Failed to connect
                CyBle_EnterLPM(CYBLE_BLESS_DEEPSLEEP);
                
            }
            else if (CyBle_GetState() == CYBLE_STATE_ADVERTISING)
            {
                //Advertising begin
            }
            
            break;
            
        case CYBLE_EVT_GATTS_READ_CHAR_VAL_ACCESS_REQ:
                //characteristic read event
            
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
    //interrupted by WDT

    /* Clear interrupts state */
	CySysWdtClearInterrupt(CY_SYS_WDT_COUNTER1_INT);
    WdtIsr_ClearPending();

    //flag allows main to recognize interrupt source
    WDTflag = 1u;

}


/*******************************************************************************
* Function Name: GPIO1_isrHandler
********************************************************************************

    Summary:
    1. Callback target upon GPIO1 interrupt.
    2. Clears interrupt on hardware and software level.
    3. Sets GPIO1flag and code continues execution after deepsleep cmd in main.

    Parameters:
    None

    Return:
    None

*******************************************************************************/
CY_ISR(GPIO1_isrHandler)
{
    GPIO1_isr_ClearPending();
    Pin_1_ClearInterrupt();

    GPIO1flag = 1u;
    
    CySysWdtResetCounters(CY_SYS_WDT_COUNTER0_RESET|CY_SYS_WDT_COUNTER1_RESET);
}


/*******************************************************************************
* Function Name: GPIO2_isrHandler
********************************************************************************

    Summary:
    1. Callback target upon GPIO2 interrupt.
    2. Clears interrupt on hardware and software level.
    3. Sets GPIO2flag and code continues execution after deepsleep cmd in main.

    Parameters:
    None

    Return:
    None

*******************************************************************************/
CY_ISR(GPIO2_isrHandler)
{
    GPIO2_isr_ClearPending();
    Pin_2_ClearInterrupt();

    GPIO2flag = 1u;
    
    CySysWdtResetCounters(CY_SYS_WDT_COUNTER0_RESET|CY_SYS_WDT_COUNTER1_RESET);
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
    
}

/*******************************************************************************
* Function Name: GPIOIntInit
********************************************************************************

    Summary:
    1. Initializes all GPIO interrupts and sets priority (arbitrary for now)

    Parameters:
    None

    Return:
    None

*******************************************************************************/
void GPIOIntInit()
{
    
    GPIO1_isr_StartEx(GPIO1_isrHandler);
    GPIO1_isr_SetPriority(3u);
    
    GPIO2_isr_StartEx(GPIO2_isrHandler);
    GPIO2_isr_SetPriority(3u);
    
}


/*******************************************************************************
* Function Name: EnableAllIsr
********************************************************************************

    Summary:
    1. Enable or disable all interrupt state routines

    Parameters:
    En - 1u to enable, 0u to disable

    Return:
    None

*******************************************************************************/
void EnableAllIsr(uint8 En)
{
    if (1u == En)
    {
        WdtIsr_Enable();
        GPIO1_isr_Enable();
        GPIO2_isr_Enable();
    }
    else
    {
        WdtIsr_Disable();
        GPIO1_isr_Disable();
        GPIO2_isr_Disable();
    }
}

int16 PollADC()
{
    int16 output;
    uint32 vnode;
    /* Wakeup requires some start time that isn't inherently handled
    It's definitely relative from testing. Think it's ~1 to 1.5 conversion sequence times
    just leaving 1ms for now, can tweak to clock cycles if needed*/

    ADC_SAR_Seq_Wakeup();
    
    //Apply voltage to divider
    Pin_3_Write(0u);
    
    CyDelay(1u);
    
    ADC_SAR_Seq_StartConvert();
    ADC_SAR_Seq_IsEndConversion(ADC_SAR_Seq_WAIT_FOR_RESULT);
    
    //voltage divider correction factor approximately equal to (6.8+27)/6.8
    vnode = ADC_SAR_Seq_GetResult16(CH0_N) * 4.9706;
    
    Pin_3_Write(1u);
    
    output = ADC_SAR_Seq_CountsTo_mVolts(CH0_N, vnode) + 285;
    ADC_SAR_Seq_Sleep();
    
    return output;
}

/* [] END OF FILE */
