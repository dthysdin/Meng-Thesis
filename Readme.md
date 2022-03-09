
Master of Engineering: Electrical Engineering.
===================

## ALICE CRU USER LOGIC 



## Introduction
___
The ReadoutCard module is a C++ library that provides a high-level interface for accessing and controlling 
high-performance data acquisition PCIe cards.

Included in the library are several supporting command-line utilities for listing cards, accessing registers, 
performing tests, maintenance, benchmarks, etc. See the section 'Utility programs' for more information. 

If you are just interested in reading and writing to the BAR, without particularly high performance requirements,
feel free to skip ahead to the section "Python interface" for the most convenient way to do so.

The library currently supports the C-RORC and CRU cards.


