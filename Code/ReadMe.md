<!--
Title:              MID User Logic
Author(s):          Orcel Thys
Date Created:       20 September 2020
Date (Last) Edited: 07 May 2021
-->
## **CRU MID user logic** 
+ UL version  :  v2
+ RDH version :  v6

### **Preface**
___
The current user logic is still under development. 
+ **hdl** contains the hdl files.
+ **ip** contains the ip files.

### **Description**
___
The UL uses as input 16 GBT links in a continuous readout mode.
It has the ability to perform zero suppression, decode, merge, and forward data to EPs using the X_datapathlink (LINKID = 15).
To reduce the amount of data transfered to EPs, the UL is using one RDH for 8 associated GBT links. 
                                                   
### **Compilation** 
___
All necessary files are declared in the **manisfest.qsf**                                             
The compilation of the MID-UL is perform under **../cru-fw/preint/syn-mid** using the following commands:                        
`` make ip_gen; make synthesis`` 

### **SRAM Object File (SOF)**
___
One may skip the compilation and download all the necessary files to program the FPGA in the following link: 
[compilation files](https://cernbox.cern.ch/index.php/s/MsBaagiMqrSjkGk)

### **Programation of the FPGA**  
___
The programation of the FPGA **cru.sof** file is perform under **../cru-fw/preint/syn-mid** using the following commands:
``/home/cru/intelFPGA_pro/18.1/quartus/bin/quartus_pgm -c 1 -z --mode=JTAG --operation="p;cru.sof@1"``                                       
In this case ``QUARTUS_PROGRAMMER_PATH = ../cru/intelFPGA_pro/18.1/quartus/bin/``


### **Avalon Registers**
___
The avalon allows to control the user logic via the PCIe BAR2 accesses

| MODULE      | BAR | ADDR           | ADDR NAME                     | DESCRIPTION                               | W/R |
|-------------|-----|----------------|-------------------------------|-------------------------------------------|-----|
| MID-UL      | 2   | 0x00c8_0000    | add_user_logic_mid_reset      | MID internal reset                        | W   |  
| MID-UL      | 2   | 0x00C8_0004    | add_user_logic_mid_cruid      | MID internal cruid                        | W/R |
| MID-UL      | 2   | 0x00C8_0008    | add_user_logic_mid_toggle     | MID togggle the GBT link registers        | W/R |
| MID-UL      | 2   | 0x00C8_000C-30 | -                             | -                                         | -   |
| MID-UL      | 2   | 0x00C8_0034    | get_status - TRG              | Get status of the user logic triggers     | R   |
| MID-UL      | 2   | 0x00C8_0038    | get_status - DWR 0            | Get status of the user logic dwrapper#0   | R   |
| MID-UL      | 2   | 0x00C8_003C    | get_status - DWR 1            | Get status of the user logic dwrapper#1   | R   |
| MID-UL      | 2   | 0x00C8_0040    | get_status - GBT 0            | Get status of the user logic gbt link#0   | R   |
| MID-UL      | 2   | 0x00C8_0044    | get_status - GBT 1            | Get status of the user logic gbt link#1   | R   |
| MID-UL      | 2   | 0x00C8_0048    | get_status - GBT 2            | Get status of the user logic gbt link#2   | R   |
| MID-UL      | 2   | 0x00C8_004C    | get_status - GBT 3            | Get status of the user logic gbt link#3   | R   |
| MID-UL      | 2   | 0x00C8_0050    | get_status - GBT 4            | Get status of the user logic gbt link#4   | R   |
| MID-UL      | 2   | 0x00C8_0054    | get_status - GBT 5            | Get status of the user logic gbt link#5   | R   |
| MID-UL      | 2   | 0x00C8_0058    | get_status - GBT 6            | Get status of the user logic gbt link#6   | R   |
| MID-UL      | 2   | 0x00C8_005C    | get_status - GBT 7            | Get status of the user logic gbt link#7   | R   |
| MID-UL      | 2   | 0x00C8_0060    | get_status - GBT 8            | Get status of the user logic gbt link#8   | R   |
| MID-UL      | 2   | 0x00C8_0064    | get_status - GBT 9            | Get status of the user logic gbt link#9   | R   |
| MID-UL      | 2   | 0x00C8_0068    | get_status - GBT 10           | Get status of the user logic gbt link#10  | R   |
| MID-UL      | 2   | 0x00C8_006C    | get_status - GBT 11           | Get status of the user logic gbt link#11  | R   |
| MID-UL      | 2   | 0x00C8_0070    | get_status - GBT 12           | Get status of the user logic gbt link#12  | R   |
| MID-UL      | 2   | 0x00C8_0074    | get_status - GBT 13           | Get status of the user logic gbt link#13  | R   |
| MID-UL      | 2   | 0x00C8_0078    | get_status - GBT 14           | Get status of the user logic gbt link#14  | R   |
| MID-UL      | 2   | 0x00C8_007C    | get_status - GBT 15           | Get status of the user logic gbt link#15  | R   |

#### **CONFIGURATION**
___
Some useful commands to configure the user logic.
Where : i#=0 refers to CRU#0 and i#=1 refers to CRU#1  

Set the reset pulse.

``roc-reg-write --i=#0 --ch=2 --add=0xc80000 --val=0x00000001``.

Set the cruid register (ID = 0 or ID = 1).

``roc-reg-write --i=#0 --ch=2 --add=0xc80004 --val=0x00000001``.

``roc-reg-write --i=#0 --ch=2 --add=0xc80004 --val=0x00000000``.

Set the toggle register (enable or disable).

``roc-reg-write --i=#0 --ch=2 --add=0xc80008 --val=0x00000001``.

``roc-reg-write --i=#0 --ch=2 --add=0xc80008 --val=0x00000000``.

             
#### **MONITORING**
___
Some useful commands to monitor the user logic signals.
Where : i#=0 refers to CRU#0 and i#=1 refers to CRU#1  

Read the cruid register value.

``roc-reg-read-range --i=#0 --ch=2 --add=0xc80004 --range=1``.

Read the toggle register value.

``roc-reg-read-range --i=#0 --ch=2 --add=0xc80008 --range=1``.

Read the trigger register value.

``roc-reg-read-range --i=#0 --ch=2 --add=0xc80034 --range=1``.

Read the status of all 16 GBT registers.

``roc-reg-read-range --i=#0 --ch=2 --add=0xc80040 --range=16``.


##### **TRIGGERS** 
___
**SOx trigger** : goes '1' after receiving SOx and '0' after receiving EOx trigger from the CRU-FW.

**EOx trigger** : goes '1' after receiving EOx and '0' after receiving SOx trigger from the CRU-FW.

**HB counter**  : counts the number of HB trigger received from the CRU-FW within SOx and EOx triggers. 

**TF counter**  : counts te number of TF received from the CRU-FW within SOx and EOx triggers.

|    TRIGGERS   | [32-bit] |                                        
|---------------|----------|
| SOx trigger   | [31]     |
| -             | [30-23]  |  
| EOx trigger   | [24]     |
| HB counter    | [23-12]  | 
| TF counter    | [11-0]   |                                         
<p>&nbsp;</p>

##### **DWRAPPER XX**
___
**DWR counter** : counts the number of packets transmitted to EPx.

**RDH counter** : counts the number of RDH updates or HB triggers pending.

**DWR fsm**     : monitors the fsm states used in the ***gbt_ulogic_mux.vhd*** 

| DWRAPPER XX   | [32-bit] |                                        
|---------------|----------|
| DWR counter   | [31-16]  |
| -             | [15-12]  | 
| RDH counter   | [11-8]   |
| DWR fsm       | [7-0]    |

 <p>&nbsp;</p>

**DWR fsm**.

The dwrapper finite state machine 

| DATA          | STATE          | DESCRIPTION                          |
|---------------|----------------|--------------------------------------|
| 0x00          | idle           | waiting for hearbeat trigger         | 
| 0x01          | hdr_val        | waiting for rdh valid bit            |    
| 0x02          | access_rdy     | waiting for payload size             | 
| 0x04          | push_gap       | push gap between sox & eox           | 
| 0x08          | push_rdh10     | push rdh(1) & (0)                    | 
| 0x10          | push_rdh32     | push rdh(3) & (2)                    | 
| 0x20          | access_pload   | access payload from different gbt    |
| 0x40          | push_load      | push payload                         |  
| 0xFF          | unknown        | #error                               |
<p>&nbsp;</p>

##### **GBT XX**
___
Each GBT xx register contains 2 faces (face A and face B), that are controlled by the toggle register mentioned above.

**FACE A** : is displayed when the toggle register bit(0) is '0'.

**FACE B** : is displayed when the toggle register bit(0) is '1'.

###### **FACE A**
___
The content of FACE A is shown below.

| GBT STATUS      | [32-bit] |                                        
|-----------------|----------|
| CrateID         | [31-28]  |
| LinkID          | [27-24]  | 
| Card monitor    | [23-12]  |
| Payload monitor | [11-4]   |
| -               | [3-0]    |


**CrateID**.

The crateID collected from the gbt xx payload, this value varies from 0x0 to 0xF.
 
**LinkID**.

The linkID assigned to the gbt xx payload, this value varies from 0x0 to 0x1.

**0x0** : link#0 is assigned to the lower gbt link of the regional crate.  
**0x1** : link#1 is assigned to the upper gbt link of the regional crate.        
   
**Card monitor**.

This signal monitors the status of the cards belonging to the gbt xx.
   
**ON** : After receiving a SOx trigger from the FEE.

**OFF** : After receiving a EOx trigger from the FEE.


| CARDS           | [12-bit] | DESCRIPTION               |                                        
|-----------------|----------|---------------------------|
| -               | [11]     | -                         |
| -               | [10]     | -                         |
| Regional#1      | [9]      | ('1' = ON ); ('0' = OFF ) | 
| Local#7         | [8]      | ('1' = ON) ; ('0' = OFF)  |
| Local#6         | [7]      | ('1' = ON) ; ('0' = OFF)  |  
| Local#5         | [6]      | ('1' = ON) ; ('0' = OFF)  |
| Local#4         | [5]      | ('1' = ON) ; ('0' = OFF)  |  
| Regional#0      | [4]      | ('1' = ON) ; ('0' = OFF)  |
| Local#3         | [3]      | ('1' = ON) ; ('0' = OFF)  | 
| Local#2         | [2]      | ('1' = ON) ; ('0' = OFF)  |
| Local#1         | [1]      | ('1' = ON) ; ('0' = OFF)  |
| Local#0         | [0]      | ('1' = ON) ; ('0' = OFF)  |
<p>&nbsp;</p>

**Payload monitor**.

This monitors the unavailability of the payload in the memories of the gbt xx.

**0x00** : payload available in both parts.                               
**0x01** : payload only unavailable in the lower part of the gbt.      
**0x10** : payload only unavailable in the higher part of the gbt.  
**0x11** : payload unavailable in both parts of the gbt.          


##### **FACE B**
___
The content of FACE B is shown below.

| GBT STATUS            | [32-bit] |                                        
|-----------------------|----------|
| GBT counter           | [31-16]  |
| Missing event counter | [15-4]   | 
| GBT fsm               | [3-0]    |
<p>&nbsp;</p>

**GBT counter** : The GBT counter counts the number of packets transmitted by the GBT xx within SOx and EOx. 

**Missing event counter** : The missing event counter counts the number of events rejected within SOx and EOx.  

**GBT fsm**.

The GBT finite state machine.

| DATA         | STATE          | DESCRIPTION                          |
|--------------|----------------|--------------------------------------|
| 0x0          | idle           | waiting for heartbeat trigger        | 
| 0x1          | pload_rdy      | waiting for payload ready bit        |    
| 0x2          | pload_rval     | waiting for payload valid bit        | 
| 0x4          | pload_access   | waiting for access from dwrappers    | 
| 0x8          | pload_send    |  pushing payload                      |  
| 0xF          | unknown        | #error                               |
<p>&nbsp;</p>

### **Authors**
___
* **Orcel Thys** - *Initial work and updates*