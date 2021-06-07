
Master of Engineering: Electrical Engineering.
===================

## TITLE: ALICE CRU USER LOGIC FIRMWARE FOR THE MID READOUT CHAIN
___

## Abstract
___



## Table of Contents
___
1. [Introduction](#introduction)
2. [Books](#Books)
2. [Chapters](#Chapters)
3. [Installation](#installation)
4. [Implementation notes](#implementation-notes)
5. [Known issues](#known-issues)


## Introduction
___
The ReadoutCard module is a C++ library that provides a high-level interface for accessing and controlling 
high-performance data acquisition PCIe cards.

Included in the library are several supporting command-line utilities for listing cards, accessing registers, 
performing tests, maintenance, benchmarks, etc. See the section 'Utility programs' for more information. 

If you are just interested in reading and writing to the BAR, without particularly high performance requirements,
feel free to skip ahead to the section "Python interface" for the most convenient way to do so.

The library currently supports the C-RORC and CRU cards.


## Usage
===================
For a simple usage example, see the program in `src/Example.cxx`.
For high-performance readout, the benchmark program `src/CommandLineUtilities/ProgramDmaBench.cxx` may be more
instructive.

Addressing
----------
ReadoutCard addresses the cards on the level of a PCIe _endpoint_.

A physical CRU is split into two logical endpoints, with each one addressing 12 of its 24 links. Endpoint 0 sees virtual links 0-11 (physical links 0-11) while endpoint 1 sees virtual links 0-11 (physical links 12-23).
Each endpoint publishes two BAR interfaces; BAR 0 for DMA orchestration and BAR 2 for everything else.
Each endpoint corresponds to a separate DMA channel.

A physical CRORC corresponds to a single endpoint, addressing its 6 links, with each one having its own BAR interface and DMA channel.

| Card        | CRU  |              | CRORC |
| ----------- | ---- | ------------ | ----- |
| Endpoint    | 0    |    1         |   0   |
| Link #      | 0-11 | 0-11 (12-23) |  0-5  |
| BAR #       | 0/2  | 0/2          |  0-5  |
| DMA Channel | 0    | 0            |  0-5  |



ReadoutCard provides several ways to address a card endpoint:

1) By the "Sequence ID"; a string with a '#' prefix followed by the sequence number which corresponds to an endpoint (e.g. `#2`).
2) By the "PCI Address"; a string following the format "[bus]:[device].[function]", made up of the PCI values which correspond to an endpoint (e.g. `3b:00.0`).
3) By the "Serial-Endpoint ID"; a string following the format "[serial]:[endpoint]", made up of the card's unique serial number and its endpoint (e.g. `1024:1`).

Addressing information is provided by the [roc-list-cards](https://github.com/AliceO2Group/ReadoutCard#roc-list-cards) tool, as shown below:

```
$ roc-list-cards
============================================================================
  #   Type   PCI Addr   Serial   Endpoint   NUMA  FW Version   UL Version
----------------------------------------------------------------------------
  0   CRORC  d8:00.0    2942     0          1     v2.7.0       n/a
  1   CRU    3b:00.0    1041     0          0     f0e4f4fa     f0e4f4fa
  2   CRU    3c:00.0    1041     1          0     f0e4f4fa     f0e4f4fa
  3   CRU    af:00.0    1239     0          1     v3.9.1       f71faa86
  4   CRU    b0:00.0    1239     1          1     v3.9.1       f71faa86
============================================================================
```

Any of the above options can be used to specify an endpoint for all the relevant [command-line utility programs](https://github.com/AliceO2Group/ReadoutCard#utility-programs), as an argument to the `--id` command-line option.

The same strings are used for the [`CardId`](https://github.com/AliceO2Group/ReadoutCard#card-id) parameter when using the ReadoutCard library.

DMA channels
-------------------
Clients can acquire a lock on a DMA channel by instantiating a `DmaChannelInterface` implementation through 
the `ChannelFactory` class. Once this object is constructed, it will provide exclusive access to the DMA channel.

The user will need to specify parameters for the channel by passing an instance of the `Parameters` 
class to the factory function. 
The most important parameters are the card ID (either a serial number or a PCI address), the channel number, and the
buffer parameters.
The serial number and PCI address (as well as additional information) can be listed using the `roc-list-cards` 
utility.
The buffer parameters specify which region of memory, or which file to map, to use as DMA buffer.
See the `Parameters` class's setter functions for more information about the options available, or the
[Parameters](#parameters-1) section of this README.

Once a DMA channel has acquired the lock, clients can call `startDma()` and start pushing superpages to the driver's
transfer queue.
The user can check how many superpage slots are still available with `getTransferQueueAvailable()`.
For reasons of performance and simplicity, the driver operates in the user's thread and thus depends on the user calling `fillSuperpages()` periodically.
This function will start data transfers, and users can check for arrived superpages using `getReadyQueueSize()`.
If one or more superpage have arrived, they can be inspected and popped using the `getSuperpage()` and 
`popSuperpage()` functions.

DMA can be paused and resumed at any time using `stopDma()` and `startDma()`

### Data Source

#### CRU

The `Data Source` parameter for the CRU DMA Channel should be used as follows:

| `DataSource`        | Data Source |
| ------------------- | ----------- |
| `Fee`               | FEE (GBT)   |
| `Ddg`               | DDG (GBT)   |
| `Internal`          | DG          |



Card Configurator
-------------------
The `CardConfigurator` class offers an interface to configure the Readout Card (_currently only implemented for the CRU_). In
order to configure the CRU one has to create a `CardConfigurator` object. The constructor can either be called with a list of
parameters, or a path to a configuration file, specifying these parameters.

### Parameters

The `CardConfigurator` utilizes the `Parameters` class, the same class where Parameters are specified for DMA channels. For the
Card Configurator, the parameters need to be initialized for the card on BAR2. The command that
achieves that is `makeParameters(cardId, 2)`. Refer to the [Parameters](#parameters-1) section for more information.

The Parameters that affect the configuration of the CRU, their possible values (in ()) and their default values (in []) are as follows:

`AllowRejection (true | false) [false]`

`CruId (0x0-0xffff) [0x0]`

`Clock (LOCAL | TTC) [LOCAL]`

`DatapathMode (PACKET | STREAMING) [PACKET]`

`DownstreamData (CTP | PATTERN | MIDTRG) [CTP]`

`GbtMode (GBT | WB) [GBT]`

`GbtMux (TTC | DDG | SWT | TTCUP |UL) [TTC]`

`LinkLoopbackEnabled (true | false) [false]`

`PonUpstreamEnabled (true | false) [false]`

`OnuAddress (0-4294967296) [0]`

`DynamicOffsetEnabled (true | false) [false]`

`TriggerWindowSize (0 - 65535) [1000]`

`GbtEnabled (true | false) [true]`

`UserLogicEnabled (true | false) [false]`

To set any of the above parameters the usual template can be followed.

```
params.set[ParamName](Parameters::[ParamName]::fromString(paramValueString));
params.set[ParamName](Parameters::[ParamName]::type::[paramValue]);
```

For example, to set the `Clock` one can use on of the following:

```
params.setClock(Parameters::Clock::fromString(clockString));
params.setClock(Parameters::Clock::type::Local);
```

The above parameters will be set for the enabled links, as specified by the `LinkMask` parameter. See the [LinkMask](#linkmask) section
for more info.

Note that for `AllowRejection`, `LinkLoopbackEnabled`, `PonUpstreamEnabled`, `DynamicOffsetEnabled`, `GbtEnabled` and `UserLogicEnabled` it is sufficient to do the following, as they are simply booleans.

```
params.setAllowRejection(true);
params.setLinkLoopbackEnabled(true);
params.setPonUpstreamEnabled(true);
params.setDynamicOffsetEnabled(true);
...
```

Likewise for `OnuAddress`, passing the hex is enough.

```
params.setOnuAddress(0x0badcafe)
```

### Configuration File

The string containing the path to the configuration file has to start with "file:", otherwise the
`CardConfigurator` will disregard it as invalid. Parameters are split between "global" and "per-link". 

The "global" parameters are:

```
clock
cruId
datapathMode
loopback
gbtMode
downstreamData
ponUpstream
onuAddress
dynamicOffsetEnabled
triggerWindowSize
gbtEnabled
UserLogicEnabled
```

The "per link" parameters are
```
enabled
gbtMux
```

The configuration file separates the parameter into three groups.

1. `[cru]`

    This parts concerns global (i.e. non-link specfic) cru configuration.

2. `[links]`

    This part refers to all the links. Configuration that goes in this group will be applied to all links, unless specifically
    setting parameters for individual links in the next section. For example to enable all links with SWT MUX by default:

    ```
    [links]
    enabled=true
    gbtMux=swt
    ```

3. `[link*]`

    This part configures only the individual link and __overrides__ any previous parameters for the specific link. For example:
    ```
    [link4]
    enabled=true
    gbtMux=ttc
    ```

An example configuration file is provided with [cru_template.cfg](cru_template.cfg).

---

An example of using the `CardConfigurator`, with `Parameters` or a config file, can be found in [ProgramConfig.cxx](src/CommandLineUtilities/ProgramConfig.cxx)

BAR interface
-------------------
Users can also get a limited-access object (implementing `BarInterface`) from the `ChannelFactory`. 
This provides an interface to reading and writing registers to the BAR.
Currently, there are no limits imposed on which registers are allowed to be read from and written to, so it is still a
"dangerous" interface. But in the future, protections may be added.

Parameters
-------------------
The `Parameters` class holds parameters used for the DMA Channel, the BAR and the Card Configurator. In order to instanciate a
`Parameters` object one needs to specify at the minimum the card ID and the channel number (i.e. the BAR# to access on the CRU).
(To be updated with CRORC. Please assume for now that everything below is CRU-specific.)

### Card ID
To make an instance of the `Parameters` class the card ID has to be passed to `makeParameters()` as a `Parameters::CardIdType` object. To construct this from a string one has to use the function `Parameters::cardIdFromString(cardIdString)`.

### Channel Number
The BAR to access. Normally DMA transactions are done through BAR0 and configuration and status reports are done through BAR2.
Also needs to be passed to `makeParameters()` resulting in the following call:
```
Parameters params = Parameters::makeParameters(cardId, channelNumber);
```

### BufferParameters
The parameters of the user-provided DMA buffer. Can be a memory address, or a file.

```
params.setBufferParameters(buffer_parameters::Memory {address, size});
params.setBufferParameters(buffer_parameters::File {pathString, size});
```

### LinkMask 
The link mask indicates which links to use. The `LinkMask` has to be set through a string that may contain comma separated
integers or ranges. For example: `0,1,2,8-10` or `0-19,21-23`.

```
params.setLinkMask(LinkMaskFromString(linkMaskString));
```

### FirmwareCheck
The firmware check parameter is by default enabled. It can be used to disable the firmware check when opening a DMA channel.
```
params.setFirmwareCheckEnabled(true);
```

### Other parameters
Operations on all other parameters can be done through setter, getter and getterRequired() functions, as seen in [Parameters.h](include/ReadoutCard/Parameters.h)

Utility programs
-------------------
The module contains some utility programs to assist with ReadoutCard debugging and administration.
For detailed information and usage examples, use a program's `--help` option.

Most programs will also provide more detailed output when given the `--verbose` option.

### roc-bar-stress
Tool to stress BAR accesses and evaluate performance.

### roc-bench-dma
DMA throughput and stress-testing benchmarks.
It may use files in these directories for DMA buffers: 
* `/var/lib/hugetlbfs/global/pagesize-2MB`
* `/var/lib/hugetlbfs/global/pagesize-1GB`
The program will report the exact file used. 
They can be inspected manually if needed, e.g. with hexdump: `hexdump -e '"%07_ax" " | " 4/8 "%08x " "\n"' [filename]`

### roc-cleanup
In the event of a serious crash, such as a segfault, it may be necessary to clean up and reset.
This tool serves this purpose and is intended to be run as root. Be aware that this will make every
running instance of readout.exe or roc-bench-dma fail.

### roc-config
Configures the CRU. Can be executed with a list of parameters, or with a [configuration file](#configuration-file). Uses the [Card Configurator](#card-configurator). For more details refer to the `--help` dialog of the binary.

### roc-example
The compiled example of `src/Example.cxx`
 
### roc-flash
Flashes firmware from a file onto the card.
Note that it is not advised to abort a flash in progress, as this will corrupt the firmware present on the card. 
Please commit to your flash.

Once a flash has completed, the host will need to be rebooted for the new firmware to be loaded.

Currently only supports the C-RORC.

### roc-flash-read
Reads from the card's flash memory.

Currently only supports the C-RORC.

### roc-list-cards
Lists the readout cards present on the system along with information documented in the following table. Every entry represents
an endpoint. For every physical card present in the system, two endpoint entries should be extended for the CRU and one for the
CRORC.

| Parameter    | Description                                                                           |
| ------------ | ------------------------------------------------------------------------------------- |
| `#`          | Sequence ID. Used for addressing within `ReadoutCard` (int)                           |
| `Type`       | The card type (`CRU` or `CRORC`)                                                      |
| `PCI Addr`   | PCI address of the card                                                               |
| `Serial`     | The serial of the card (3-5 digit int)                                                |
| `Endpoint`   | Endpoint ID (`0/1` for a CRU, `0` for a CRORC)                                        |
| `NUMA`       | NUMA node of the card (`0` or `1`)                                                    |
| `FW Version` | Firmware version installed (`vx.y.z` if identified and supported, git hash otherwise) |
| `UL Version` | User Logic version installed (git hash)                                               |

Output may be in ASCII table (default), or JSON format (`--json-out` option).

### roc-metrics
Outputs metrics for the ReadoutCards. Output may be in an ASCII table (default) or in JSON (`--json-out` option) format.

Parameter information can be extracted from the monitoring table below.

#### Monitoring metrics

To directly send metrics to the Alice O2 Monitoring library, the argument `--monitoring` is necessary.

###### Metric: `"card"`

| Value name                | Value | type   |
| ------------------------- | ----- | ------ |
| `"pciAddress"`            | -     | string |
| `"temperature"`           | -     | double |
| `"droppedPackets"`        | -     | int    |
| `"ctpClock"`              | -     | double |
| `"localClock"`            | -     | double |
| `"totalPacketsPerSecond"` | -     | int    |

| Tag key               | Value                 |
| --------------------- | --------------------- |
| `tags::Key::SerialId` | Serial ID of the card |
| `tags::Key::Endpoint` | Endpoint of the card  |
| `tags::Key::ID`       | ID of the card        |
| `tags::Key::Type`     | Type of the card      |

### roc-pkt-monitor
Monitors packet statistics per link and per CRU wrapper. Output may be in an ASCII table (default) or in JSON (`json-out` option)
format.

Parameter information can be extracted from the monitoring table below.

#### Monitoring metrics

To directly send metrics to the Alice O2 Monitoring library, the argument `--monitoring` is necessary.


##### CRU

###### Metric: `"link"`

| Value name       | Value  | Type   |
| ---------------- | ------ | ------ |
| `"pciAddress"`   | -      | string |
| `"accepted"`     | -      | int    |
| `"rejected"`     | -      | int    |
| `"forced"`       | -      | int    |

| Tag key               | Value                 |
| --------------------- | --------------------- |
| `tags::Key::SerialId` | Serial ID of the card |
| `tags::Key::Endpoint` | Endpoint of the card  |
| `tags::Key::CRU`      | ID of the CRU         |
| `tags::Key::ID`       | ID of the link        |
| `tags::Key::Type`     | `tags::Value::CRU`    |

###### `Metric: `"wrapper"`

| Value name                 | Value  | Type   |
| -------------------------- | ------ | ------ |
| `"pciAddress"`             | -      | string |
| `"dropped"`                | -      | int    |
| `"totalPacketsPerSec"`     | -      | int    |
| `"forced"`                 | -      | int    |

| Tag key               | Value                 |
| --------------------- | --------------------- |
| `tags::Key::SerialId` | Serial ID of the card |
| `tags::Key::Endpoint` | Endpoint of the card  |
| `tags::Key::CRU`      | ID of the CRU         |
| `tags::Key::ID`       | ID of the link        |
| `tags::Key::Type`     | `tags::Value::CRU`    |

### roc-reg-[read, read-range, write]
Writes and reads registers to/from a card's BAR. 
By convention, registers are 32-bit unsigned integers.
Note that their addresses are given by byte address, and not as you would index an array of 32-bit integers.

### roc-reg-modify
Modifies certain bits of a card's register through the BAR.

### roc-reset
Resets a card channel

### roc-run-script
*Deprecated, see section "Python interface"*
Run a Python script that can use a simple interface to use the library.

### roc-setup-hugetlbfs
Setup hugetlbfs directories & mounts. If using hugepages, should be run once per boot.

### roc-status
Reports status on the card's global and per-link configuration. Output may be in an ASCII table (default) or in JSON (`--json-out` option) format.

Parameter information can be extracted from the monitoring tables below. Please note that for "UP/DOWN" and "Enabled/Disabled"
states while the monitoring format is an int (0/1), in all other formats a string representation is used.

#### Monitoring status

To directly send metrics from `roc-status` to the Alice O2 Monitoring library, the argument `--monitoring` is necessary. The
metric format for the CRORC and the CRU is different, as different parameters are relevant for each card type.

##### Resource usage

Fitter Status : Successful - Fri May  7 10:59:15 2021
Quartus Prime Version : 18.1.0 Build 222 09/21/2018 SJ Pro Edition
Revision Name : cru
Top-level Entity Name : top
Family : Arria 10
Device : 10AX115S3F45E2SG
Timing Models : Final
Logic utilization (in ALMs) : 330,702 / 427,200 ( 77 % )
Total registers : 381550
Total pins : 369 / 960 ( 38 % )
Total virtual pins : 0
Total block memory bits : 22,536,168 / 55,562,240 ( 41 % )
Total RAM Blocks : 2,050 / 2,713 ( 76 % )
Total DSP Blocks : 0 / 1,518 ( 0 % )
Total HSSI RX channels : 41 / 72 ( 57 % )
Total HSSI TX channels : 41 / 72 ( 57 % )
Total PLLs : 59 / 144 ( 41 % )


___
Known issues
===================
C-RORC concurrent channels
-------------------
The issue has occurred on Dell R720 servers.
