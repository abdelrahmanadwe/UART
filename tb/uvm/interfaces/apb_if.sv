`timescale 1ns/1ps

interface apb_if (input logic PCLK, input logic PRESETn);
  logic [4:0]  PADDR;
  logic        PSEL;
  logic        PENABLE;
  logic        PWRITE;
  logic [31:0] PWDATA;
  logic [31:0] PRDATA;
  logic        PREADY;
  logic        PSLVERR;

  // Driver clocking block
  clocking cb @(posedge PCLK);
    default input #1ns output #1ns;
    output PADDR, PSEL, PENABLE, PWRITE, PWDATA;
    input  PRDATA, PREADY, PSLVERR;
  endclocking

  // Monitor clocking block
  clocking monitor_cb @(posedge PCLK);
    default input #1ns output #1ns;
    input PADDR, PSEL, PENABLE, PWRITE, PWDATA, PRDATA, PREADY, PSLVERR;
  endclocking

  modport driver  (clocking cb, input PCLK, PRESETn);
  modport monitor (clocking monitor_cb, input PCLK, PRESETn);

  // ===========================================================================
  // SystemVerilog Assertions (SVA) for APB Protocol Verification
  // ===========================================================================

  // 1. PENABLE must rise exactly one clock cycle after PSEL rises
  property p_penable_rise;
    @(posedge PCLK) disable iff (!PRESETn)
    PSEL && !PENABLE |=> PENABLE;
  endproperty
  assert_penable_rise: assert property(p_penable_rise);

  // 2. PENABLE must fall on the clock cycle after PREADY is high (end of transfer)
  property p_penable_fall;
    @(posedge PCLK) disable iff (!PRESETn)
    PSEL && PENABLE && PREADY |=> !PENABLE;
  endproperty
  assert_penable_fall: assert property(p_penable_fall);

  // 3. PADDR and PWRITE must remain stable during wait states (PSEL & PENABLE high but PREADY low)
  property p_apb_stable_during_wait;
    @(posedge PCLK) disable iff (!PRESETn)
    PSEL && PENABLE && !PREADY |=> $stable(PADDR) && $stable(PWRITE);
  endproperty
  assert_apb_stable_during_wait: assert property(p_apb_stable_during_wait);

  // 4. Alignment checking: PSLVERR must be asserted if address is not 4-byte aligned (last 2 bits != 2'b00)
  property p_pslverr_alignment;
    @(posedge PCLK) disable iff (!PRESETn)
    PSEL && PENABLE && (PADDR[1:0] != 2'b00) |-> PSLVERR == 1'b1;
  endproperty
  assert_pslverr_alignment: assert property(p_pslverr_alignment);

  // Cover properties to report assertion hits in coverage reports
  cover_penable_rise:            cover property(p_penable_rise);
  cover_penable_fall:            cover property(p_penable_fall);
  cover_apb_stable_during_wait:  cover property(p_apb_stable_during_wait);
  cover_pslverr_alignment:       cover property(p_pslverr_alignment);

endinterface
