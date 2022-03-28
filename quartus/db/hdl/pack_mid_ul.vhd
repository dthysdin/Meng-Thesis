-------------------------------------------------------------------------------
--  Cape Peninsula Universty of Technology --
------------------------------------------------------------------------------
-- Project   : Muon Identifier User Logic 
-------------------------------------------------------------------------------
-- File      : pack_mid_ul.vhd
-- Author    : Orcel Thys <dieuveil.orcel.thys-dingou@cern.ch>
-- Student No: 214349721
-- Company   : NRF iThemba LABS
-- Created   : 2020-06-24
-- Platform  : Quartus Pro 18.1
-- Standard  : VHDL'93'
-- Version   : 0.7
-------------------------------------------------------------------------------
-- last changes 
-- <13/10/2020> change the component declarations 
-- <04/12/2020> change the component declarations 
-- <13/02/2021> change the component declarations 
-------------------------------------------------------------------------------
-- TODO:  Completed 
-- <nothing to do>
-------------------------------------------------------------------------------
-- Description:
-- MID user logic package
-- Mostly used for component declarations, types and records.
-------------------------------------------------------------------------------
-- Copyright (c) 2018
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;
-- Specific package 
use work.pack_cru_core.all;

package pack_mid_ul is  
    --=======================================================--
	-- constant declaration 
	--=======================================================--
	constant c_NUM_GBT_USED     : integer := 2;  -- number of gbt links used for the MID readout chain (16 by default ) 
	--=======================================================--
	-- record declaration 
	--=======================================================--
	type t_mid_monitor is record
	gbt : Array32bit(c_NUM_GBT_USED-1 downto 0);                  -- monitor gbt links 
	dw  : Array32bit(1 downto 0);                                 -- monitor d-wrappers
	trg : std_logic_vector(31 downto 0);                          -- monitor triggers
	end record t_mid_monitor;

	type t_mid_config is record
	mid_rst     : std_logic;                                      -- MID reset 
	mid_cruid   : std_logic_vector(3 downto 0);                   -- MID CRUID 
	mid_switch  : std_logic_vector(3 downto 0);                   -- MID switch
    mid_mapping : std_logic_vector(4*c_NUM_GBT_USED-1 downto 0);  -- MID mapping  
	mid_sync    : std_logic_vector(11 downto 0);                  -- MID synchronization 
	end record t_mid_config;

	type t_mid_gbt is record
	en    : std_logic;  			        -- sel + ready                    		
	valid : std_logic;  			        -- valid (1 out of 6 clk @ 240 MHz)                    		                   	
	data  : std_logic_vector(79 downto 0);	-- data 
	end record t_mid_gbt;
	
	type t_mid_ttc is record                
	trg   : std_logic_vector(31 downto 0);	-- trigger 
	bcid  : std_logic_vector(15 downto 0);	-- bunch crossing 
	orbit : std_logic_vector(31 downto 0);	-- orbit 
	end record t_mid_ttc; 

	type t_mid_pulse is record
	sox  : std_logic;                        -- sox trigger pulse              
	hbt  : std_logic;                        -- heartbeat trigger pulse
	tfm  : std_logic;                        -- timeframe trigger pulse 
	sel  : std_logic;                        -- heartbeat trigger sel pulse 
	eox  : std_logic;                        -- eox trigger pulse 
	end record t_mid_pulse; 

	type t_mid_mode is record
	continuous : std_logic;                         -- continuous mode                                       
	triggered  : std_logic;                         -- triggered mode 
	triggered_data : std_logic_vector(15 downto 0); -- triggered mode bcid data 
	end record t_mid_mode;

	type t_mid_hdr is record
	valid : std_logic;                      -- valid 
	ready : std_logic;                      -- ready
	cnt   : std_logic_vector(2 downto 0);   -- counter 
	data  : t_mid_ttc;                      -- data
	end record t_mid_hdr;

	type t_mid_pkt is record
	valid : std_logic;                       -- valid 
	ready : std_logic;                       -- ready 
	data  : std_logic_vector(255 downto 0);  -- data
	end record t_mid_pkt;

	type t_mid_pload is record
    valid   : std_logic;                      -- valid
	ready   : std_logic;                      -- ready
	data    : Array16bit(1 downto 0);         -- data
	end record t_mid_pload;

	type t_mid_daq_handshake is record 
	orb   : std_logic;
	eox   : std_logic;
	close : std_logic; 
	end record t_mid_daq_handshake;

	type t_mid_elink_monit is record
	daq_enable        : std_logic;                     -- daq enable 
	pending_cards     : std_logic;                     -- pending cards (buffer not empty)
	active_cards      : std_logic_vector(4 downto 0);  -- active cards (sox received) 
	inactive_cards    : std_logic_vector(4 downto 0);  -- inactive cards (eox received)
	crateID           : std_logic_vector(3 downto 0);  -- crate ID 
	fsm               : std_logic_vector(3 downto 0);  -- fsm state machine status
	missing_event_cnt : std_logic_vector(11 downto 0); -- missing event counter
	end record;

	type t_mid_pload_monit is record
    missing_load_cnt   : Array16bit(1 downto 0); -- valid
	end record t_mid_pload_monit;

	type t_mid_trans_monit is record
    pushed_cnt : std_logic_vector(15 downto 0);
	fsm        : std_logic_vector(3 downto 0);
	end record t_mid_trans_monit;

	type t_mid_gbt_datapath is record                    		
	done  : std_logic; 			              -- end                     		
	valid : std_logic;      	              -- valid                	
	data  : std_logic_vector(255 downto 0);   -- data 	
	end record t_mid_gbt_datapath;

	type t_mid_dw_datapath is record
	sop   : std_logic; 			              -- sop                     		
	eop   : std_logic; 			              -- eop                    		
	valid : std_logic;      	              -- val               	
	data  : std_logic_vector(255 downto 0);   -- data 	
	end record t_mid_dw_datapath;
	--=======================================================--
	-- type declaration 
	--=======================================================--
	type t_mid_gbt_array is array (natural range <>) of t_mid_gbt;
	type t_mid_pkt_array is array (natural range <>) of t_mid_pkt;
	type t_mid_gbt_datapath_array is array (natural range <>) of t_mid_gbt_datapath;
	type t_mid_dw_datapath_array is array (natural range <>) of t_mid_dw_datapath;
	type t_mid_mode_array is array (natural range <>) of t_mid_mode;
	type t_mid_daq_handshake_array is array (natural range <>) of t_mid_daq_handshake;
	type t_mid_elink_monit_array is array (natural range <>) of t_mid_elink_monit;
	type t_mid_Array168bit is array (natural range <>) of std_logic_vector(167 downto 0);
	type t_mid_Array40bit is array (natural range <>) of std_logic_vector(39 downto 0);
	type t_mid_Array12bit is array (natural range <>) of std_logic_vector(11 downto 0);
	--=======================================================--
	-- component declaration 
	--=======================================================--
	component regional_decoder is 
	port (
	-------------------------------------------------------------------
	clk_240	    : in std_logic;
	--	
	reset_i     : in std_logic;							 
	--
	reg_en_i    : in std_logic;	
	reg_val_i   : in std_logic;													
	reg_data_i  : in std_logic_vector(7 downto 0);   
	--
	reg_val_o   : out std_logic;                     
	reg_data_o  : out std_logic_vector(39 downto 0)  
	------------------------------------------------------------------- 
		);
	end component regional_decoder;
	 
	component regional_control is 
	generic (g_LINK_ID : integer; g_REGIONAL_ID : integer);
	port (
	-------------------------------------------------------------------
	clk_240	       : in std_logic;
	--	
	reset_i	       : in std_logic;							 
	--
	daq_enable_i   : in std_logic;	
	daq_resume_i   : in t_mid_daq_handshake;
	daq_pause_o    : out t_mid_daq_handshake;
	--		 									
	ttc_mode_i     : in t_mid_mode;
	mid_sync_i     : in std_logic_vector(11 downto 0);
	-- 
	reg_val_i      : in std_logic;								 
	reg_data_i     : in std_logic_vector(39 downto 0);		 
	reg_full_i     : in std_logic;								
	reg_inactive_i : in std_logic;						
	--
	reg_val_o      : out std_logic;								
	reg_data_o     : out std_logic_vector(39 downto 0);	 								 
	reg_active_o   : out std_logic;
	reg_overflow_o : out std_logic;
	reg_missing_o  : out std_logic_vector(11 downto 0);
	reg_crateID_o  : out std_logic_vector(3 downto 0);	
	reg_crateID_val_o : out std_logic	
	-------------------------------------------------------------------
	 );  
	end component regional_control;
	
	component regional_elink is
	generic (g_LINK_ID : integer; g_REGIONAL_ID : integer);
	port (
	-------------------------------------------------------------------
	clk_240	      : in std_logic;
	-- 	
	reset_i	      : in std_logic;
	--
	daq_enable_i  : in std_logic;	
	daq_resume_i  : in t_mid_daq_handshake;
	daq_pause_o   : out t_mid_daq_handshake;
	--						
	gbt_val_i     : in std_logic;	
	gbt_data_i    : in std_logic_vector(7 downto 0);							
	--						
	ttc_mode_i    : in t_mid_mode;	
	mid_sync_i    : in std_logic_vector(11 downto 0);					
	--							 	
	reg_rdreq_i   : in std_logic;														
	--	 
	reg_val_o     : out std_logic;														
	reg_data_o    : out std_logic_vector(39 downto 0); 							
	reg_empty_o   : out std_logic;	
	reg_afull_o   : out std_logic;														
	reg_active_o  : out std_logic;							 
	reg_inactive_o: out std_logic;
	reg_missing_o : out std_logic_vector(11 downto 0);
	reg_crateID_o : out std_logic_vector(3 downto 0);
	reg_crateID_val_o : out std_logic	 
	-------------------------------------------------------------------
	 );  
	end component regional_elink;	
	
	component local_decoder is
	generic (g_LINK_ID : integer; g_REGIONAL_ID : integer; g_LOCAL_ID : integer);
	port (
	-------------------------------------------------------------------
	clk_240	       : in std_logic;
	--	
	reset_i	       : in std_logic;							  
	--
	loc_en_i       : in std_logic;
	loc_val_i      : in std_logic;							 						 
	loc_data_i     : in std_logic_vector(7 downto 0);	 
	--
	loc_val_o      : out std_logic;							
	loc_data_o     : out std_logic_vector(167 downto 0) 
	-------------------------------------------------------------------
	 );  
	end component local_decoder;
	
	component local_control is
	generic (g_LOCAL_ID : integer);
	port (
	-------------------------------------------------------------------
	clk_240	       : in std_logic;								
	--
	reset_i        : in std_logic;
	--
	daq_enable_i   : in std_logic;	
	daq_resume_i   : in t_mid_daq_handshake;
	daq_pause_o    : out t_mid_daq_handshake;
	--			 									
	ttc_mode_i     : in t_mid_mode;
	mid_sync_i     : in std_logic_vector(11 downto 0);
	--
	loc_val_i      : in std_logic;								
	loc_data_i     : in std_logic_vector(167 downto 0);	
	loc_full_i     : in std_logic;							 
	loc_inactive_i : in std_logic;								
	--
	loc_val_o      : out std_logic;								
	loc_data_o     : out std_logic_vector(167 downto 0);	 								
	loc_active_o   : out std_logic;
	loc_missing_o  : out std_logic_vector(11 downto 0);
	loc_overflow_o : out std_logic
	-------------------------------------------------------------------
	 );  
	end component local_control;
	
	component local_elink is
	generic (g_LINK_ID : integer; g_REGIONAL_ID : integer; g_LOCAL_ID : integer);
	port (
	-------------------------------------------------------------------
	clk_240	       : in std_logic;				           
	--    
	reset_i        : in std_logic;
	--
	daq_enable_i   : in std_logic;	
	daq_resume_i   : in t_mid_daq_handshake;
	daq_pause_o    : out t_mid_daq_handshake;
	--										
	gbt_val_i      : in std_logic;
	gbt_data_i     : in std_logic_vector(7 downto 0);								
	--		 									 
	ttc_mode_i     : in t_mid_mode;	
	mid_sync_i     : in std_logic_vector(11 downto 0);						
	--
	loc_rdreq_i    : in std_logic;																
	--
	loc_val_o      : out std_logic;								 
	loc_data_o     : out std_logic_vector(167 downto 0);	 								 
	loc_empty_o    : out std_logic;		
	loc_afull_o    : out std_logic;							 								
	loc_active_o   : out std_logic;
	loc_missing_o  : out std_logic_vector(11 downto 0);								 
	loc_inactive_o : out std_logic               
	-------------------------------------------------------------------
	 );  
	end component local_elink;
	
	component elink_mux is
	generic (g_LINK_ID : integer; g_REGIONAL_ID : integer);
	port (
	-----------------------------------------------------------------------
	clk_240	       : in std_logic;					
	--	
	reset_i        : in std_logic;
	--
	sox_pulse_i    : in std_logic;
	eox_pulse_i    : in std_logic;
	sel_pulse_i    : in std_logic;	
	tfm_pulse_i    : in std_logic;
	--
	packet_full_i  : in std_logic;
	--									 	
	gbt_val_i      : in std_logic;
	gbt_data_i     : in std_logic_vector(39 downto 0);			
	--							
	ttc_mode_i     : in t_mid_mode;
	mid_sync_i     : in std_logic_vector(11 downto 0);													
	--
	elink_monitor_o : out t_mid_elink_monit;
	--
	mux_val_o	   : out std_logic;
	mux_stop_o	   : out std_logic;
	mux_data_o	   : out std_logic_vector(7 downto 0)

	);  
	end component elink_mux;
	
	component packetizer is
	generic ( g_LINK_ID : integer);
	port (
	-----------------------------------------------------------------------
	clk_240           : in std_logic;
	--
    reset_i           : in std_logic;
	--
	sox_pulse_i       : in std_logic;
	eox_pulse_i       : in std_logic;
	sel_pulse_i       : in std_logic;	
	tfm_pulse_i       : in std_logic;
	--		
	ttc_mode_i        : in t_mid_mode;
	mid_sync_i        : in std_logic_vector(11 downto 0);
	-- 						   
	gbt_val_i         : in std_logic;	
	gbt_data_i        : in std_logic_vector(79 downto 0);
	--												 						
	packet_rdreq_i    : in std_logic_vector(1 downto 0);
	packet_o          : out t_mid_pkt_array(1 downto 0);
	packet_monitor_o  : out t_mid_elink_monit_array(1 downto 0);	
	--								
	payload_o         : out t_mid_pload;
	payload_empty_o   : out std_logic_vector(1 downto 0);	
	payload_monitor_o : out t_mid_pload_monit;			
	payload_rdreq_i   : in std_logic_vector(1 downto 0)							
	------------------------------------------------------------------------
				);  
	end component packetizer;
	
	component header is
	port (
	-----------------------------------------------------------------------
	clk_240	        : in std_logic;
	--	
	reset_i         : in std_logic;                  
    --
	ttc_data_i      : in t_mid_ttc;
    ttc_pulse_i     : in t_mid_pulse;
	--
	header_rdreq_i  : in std_logic;
	header_o        : out t_mid_hdr
	------------------------------------------------------------------------
       );    
	end component header;
	
	component transmitter is
	port (
	-----------------------------------------------------------------------
	clk_240		       : in std_logic;
	--					                     
	reset_i		       : in std_logic; 										
	--
	packet_i           : in t_mid_pkt_array(1 downto 0);				 
	packet_rdreq_o     : out std_logic_vector(1 downto 0);				
	--
	payload_i          : in t_mid_pload;	
	payload_empty_i    : in std_logic_vector(1 downto 0);						 									
	payload_rdreq_o    : out std_logic_vector(1 downto 0);				
	-- 
	dw_limited_cnt_i  : in std_logic_vector(15 downto 0);  
	--
	gbt_access_val_i  : in std_logic;
	gbt_access_ack_i  : in std_logic;										
	gbt_access_req_o  : out std_logic;			
	-- 
	gbt_datapath_o   : out t_mid_gbt_datapath;								 
	gbt_datapath_cnt_o : out std_logic_vector(15 downto 0);
	-- 
	trans_monitor_o  : out t_mid_trans_monit										
       );  
	end component transmitter;
	
	component gbt_ulogic is
	generic (g_LINK_ID : integer);
	port (
	-----------------------------------------------------------------------
	clk_240            : in std_logic;		
    --	
	reset_i            : in std_logic;		
	--					
	ttc_mode_i         : in t_mid_mode;
    ttc_sox_pulse_i    : in std_logic;
	ttc_eox_pulse_i    : in std_logic;
	ttc_sel_pulse_i    : in std_logic;	
	ttc_tfm_pulse_i    : in std_logic;
	--
	gbt_val_i          : in std_logic;
	gbt_data_i         : in std_logic_vector(79 downto 0);		
	-- 
	dw_limited_cnt_i   : in std_logic_vector(15 downto 0);  
	-- 
	mid_switch_i       : in std_logic_vector(3 downto 0);
	mid_sync_i         : in std_logic_vector(11 downto 0);
	-- 
	gbt_monitor_o      : out std_logic_vector(31 downto 0);
	-- 
	gbt_access_val_i   : in std_logic;
	gbt_access_ack_i   : in std_logic;		
	gbt_access_req_o   : out std_logic;		
	-- 
	gbt_datapath_o     : out t_mid_gbt_datapath; 
	gbt_datapath_cnt_o : out std_logic_vector(15 downto 0)
				);   
	end component gbt_ulogic;
	
	component gbt_ulogic_mux is
	generic (g_DWRAPPER_ID : integer; g_HALF_NUM_GBT_USED : integer);
	port (
	-----------------------------------------------------------------------
	clk_240      : in std_logic;
    --
	reset_i	     : in std_logic;													
	--
	afull_i 	 : in std_logic;	
	--		
	ttc_data_i	 : in t_mid_ttc;
	ttc_mode_i   : in t_mid_mode;
    ttc_pulse_i  : in t_mid_pulse;
	--	
	mid_rx_bus_i : in t_mid_gbt_array(g_HALF_NUM_GBT_USED-1 downto 0);
	--
	mid_cruid_i  : in std_logic_vector(3 downto 0);
	mid_switch_i : in std_logic_vector(3 downto 0);
	mid_sync_i   : in std_logic_vector(11 downto 0);
    --
	dw_monitor_o       : out std_logic_vector(31 downto 0);		
	gbt_monitor_o      : out Array32bit(g_HALF_NUM_GBT_USED-1 downto 0);	
	--
	dw_datapath_o      : out t_mid_dw_datapath	
	------------------------------------------------------------------------
				);  
	end component gbt_ulogic_mux;
	
	component gbt_ulogic_select is
	generic ( g_NUM_GBT_INPUT: integer; g_NUM_GBT_OUTPUT : natural); 
	port (
	-------------------------------------------------------------------
	clk_240	        : in std_logic;
	mid_mapping_i   : in std_logic_vector(4*g_NUM_GBT_OUTPUT-1 downto 0);  
	gbt_rx_ready_i	: in std_logic_vector(g_NUM_GBT_INPUT-1 downto 0);
	gbt_rx_bus_i	: in t_cru_gbt_array(g_NUM_GBT_INPUT-1 downto 0);
	mid_rx_bus_o	: out t_mid_gbt_array(g_NUM_GBT_OUTPUT-1 downto 0)
	-------------------------------------------------------------------
	 );  
	end component gbt_ulogic_select;
	
	component avalon_ulogic is
	port (
	-----------------------------------------------------------------------
	mms_clk     : in  std_logic;
	mms_reset 	: in  std_logic;
	mms_waitreq : out std_logic ;
	mms_addr    : in  std_logic_vector(23 downto 0);
	mms_wr		: in  std_logic;
	mms_wrdata	: in  std_logic_vector(31 downto 0);
	mms_rd		: in  std_logic;
	mms_rdval	: out std_logic;
	mms_rddata	: out std_logic_vector(31 downto 0);
	--
	monitor     : in t_mid_monitor;
    config      : out t_mid_config           
	------------------------------------------------------------------------
				);  
	end component avalon_ulogic;

	component ttc_ulogic is
	port (
	-----------------------------------------------------------------------
	clk_240	      : in std_logic;
	-- 	
	mid_reset_i   : in std_logic; 
	mid_sync_i    : in std_logic_vector(11 downto 0);
	--
    sync_reset_o  : out std_logic; 
	--
	ttc_rxd_i     : in std_logic_vector(199 downto 0);
    ttc_rxvalid_i : in std_logic;   
    ttc_rxready_i : in std_logic;
	--
	ttc_data_o    : out t_mid_ttc;
    ttc_mode_o    : out t_mid_mode;
    ttc_pulse_o   : out t_mid_pulse;
    ttc_monitor_o : out std_logic_vector(31 downto 0)
	------------------------------------------------------------------------
					);  
	end component ttc_ulogic;
	
	component fifo_168x64 is
	port (
		data  : in  std_logic_vector(167 downto 0) := (others => '0'); --  fifo_input.datain
		wrreq : in  std_logic                      := '0';             --            .wrreq
		rdreq : in  std_logic                      := '0';             --            .rdreq
		clock : in  std_logic                      := '0';             --            .clk
		sclr  : in  std_logic                      := '0';             --            .sclr
		q     : out std_logic_vector(167 downto 0);                    -- fifo_output.dataout
		full  : out std_logic;                                         --            .full
		empty : out std_logic                                          --            .empty
	);
	end component;
	
	component fifo_168x128 is
	port (
		data  : in  std_logic_vector(167 downto 0) := (others => '0'); --  fifo_input.datain
		wrreq : in  std_logic                      := '0';             --            .wrreq
		rdreq : in  std_logic                      := '0';             --            .rdreq
		clock : in  std_logic                      := '0';             --            .clk
		sclr  : in  std_logic                      := '0';             --            .sclr
		q     : out std_logic_vector(167 downto 0);                    -- fifo_output.dataout
		full  : out std_logic;                                         --            .full
		usedw	: out std_logic_vector(6 downto 0);		       --	     .usedw
		empty : out std_logic                                          --            .empty
	);
	end component;
	
	component fifo_16x8 is
	port (
		data  : in  std_logic_vector(15 downto 0) := (others => '0'); --  fifo_input.datain
		wrreq : in  std_logic                     := '0';             --            .wrreq
		rdreq : in  std_logic                     := '0';             --            .rdreq
		clock : in  std_logic                     := '0';             --            .clk
		sclr  : in  std_logic                     := '0';             --            .sclr
		q     : out std_logic_vector(15 downto 0);                    -- fifo_output.dataout
		full  : out std_logic;                                        --            .full
		empty : out std_logic                                         --            .empty
	);
	end component;
	
	component fifo_256x256 is
	port (
		data  : in  std_logic_vector(255 downto 0) := (others => '0'); --  fifo_input.datain
		wrreq : in  std_logic                      := '0';             --            .wrreq
		rdreq : in  std_logic                      := '0';             --            .rdreq
		clock : in  std_logic                      := '0';             --            .clk
		sclr  : in  std_logic                      := '0';             --            .sclr
		q     : out std_logic_vector(255 downto 0);                    -- fifo_output.dataout
		full  : out std_logic;                                         --            .full
		empty : out std_logic                                          --            .empty
	);
	end component;
	
	component fifo_40x64 is
	port (
		data  : in  std_logic_vector(39 downto 0) := (others => '0'); --  fifo_input.datain
		wrreq : in  std_logic                     := '0';             --            .wrreq
		rdreq : in  std_logic                     := '0';             --            .rdreq
		clock : in  std_logic                     := '0';             --            .clk
		sclr  : in  std_logic                     := '0';             --            .sclr
		q     : out std_logic_vector(39 downto 0);                    -- fifo_output.dataout
		full  : out std_logic;                                        --            .full
		empty : out std_logic                                         --            .empty
	);
	end component;
	
	component fifo_40x128 is
	port (
		data  : in  std_logic_vector(39 downto 0) := (others => '0'); --  fifo_input.datain
		wrreq : in  std_logic                     := '0';             --            .wrreq
		rdreq : in  std_logic                     := '0';             --            .rdreq
		clock : in  std_logic                     := '0';             --            .clk
		sclr  : in  std_logic                     := '0';             --            .sclr
		q     : out std_logic_vector(39 downto 0);                    -- fifo_output.dataout
		full  : out std_logic;                                        --            .full
		usedw	: out std_logic_vector(6 downto 0);		      --	    .usedw
		empty : out std_logic                                         --            .empty
	);
	end component;

	component fifo_64x8 is
	port (
		data  : in  std_logic_vector(63 downto 0) := (others => '0'); --  fifo_input.datain
		wrreq : in  std_logic                     := '0';             --            .wrreq
		rdreq : in  std_logic                     := '0';             --            .rdreq
		clock : in  std_logic                     := '0';             --            .clk
		sclr  : in  std_logic                     := '0';             --            .sclr
		q     : out std_logic_vector(63 downto 0);                    -- fifo_output.dataout
		full  : out std_logic;                                        --            .full
		usedw	: out std_logic_vector(2 downto 0);		      --	    .usedw
		empty : out std_logic                                         --            .empty
	);
	end component fifo_64x8;

end pack_mid_ul;
 
package body pack_mid_ul is 

--	-- <sum_Array16bit>
--	function sum_Array16bit(din : Array16bit) return unsigned is
--	 variable sum_out : unsigned(15 downto 0);
--	 variable dout : unsigned(15 downto 0);
--    begin 
--	 -- default 
--	 sum_out := (others => '0');
--	 for i in din'reverse_range loop 
--	  sum_out := sum_out + unsigned(din(i));
--	 end loop;
--	 dout := sum_out;
--	 return dout;
--	end function sum_Array16bit;
--
--	-- <sum_Array12bit>
--	function sum_Array12bit(din : t_mid_missing_cnt_array) return unsigned is
--	 variable sum_out : unsigned(11 downto 0);
--	 variable dout : unsigned(11 downto 0);
--	begin 
--	 -- default 
--	 sum_out := (others => '0');
--	 for i in din'reverse_range loop 
--	  sum_out := sum_out + unsigned(din(i));
--	 end loop;
--	 dout := sum_out;
--	 return dout;
--	end function sum_Array12bit;

end pack_mid_ul;
--=============================================================================
-- package body end
--=============================================================================