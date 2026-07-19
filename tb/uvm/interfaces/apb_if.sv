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

  // Switch to enable checks
  bit has_checks;
  
  initial begin
    has_checks = 1;
  end

  // ===========================================================================
  // SystemVerilog Assertions (SVA) for APB Protocol Verification
  // ===========================================================================

  sequence setup_phase_s;
    (PSEL == 1) && ($rose(PSEL) || ($past(PENABLE) == 1 && $past(PREADY) == 1));
  endsequence
    
  sequence access_phase_s;
    (PSEL == 1) && (PENABLE == 1);
  endsequence

  // Properties and assertions for PENABLE
  property penable_at_setup_phase_p;
    @(posedge PCLK) disable iff(!PRESETn || !has_checks)
    setup_phase_s |-> PENABLE == 0;
  endproperty
  assert_penable_at_setup_phase: assert property(penable_at_setup_phase_p) else
    $error("PENABLE at \"Setup Phase\" is not equal to 0");

  property penable_entering_access_phase_p;
    @(posedge PCLK) disable iff(!PRESETn || !has_checks)
    setup_phase_s |=> PENABLE == 1;
  endproperty
  assert_penable_entering_access_phase: assert property(penable_entering_access_phase_p) else
    $error("PENABLE when entering \"Access Phase\" did not became 1");

  property penable_exiting_access_phase_p;
    @(posedge PCLK) disable iff(!PRESETn || !has_checks)
    access_phase_s and (PREADY == 1) |=> PENABLE == 0;
  endproperty
  assert_penable_exiting_access_phase: assert property(penable_exiting_access_phase_p) else
    $error("PENABLE when exiting \"Access Phase\" did not became 0");

  property penable_stable_at_access_phase_p;
    @(posedge PCLK) disable iff(!PRESETn || !has_checks)
    access_phase_s |-> PENABLE == 1;
  endproperty
  assert_penable_stable_at_access_phase: assert property(penable_stable_at_access_phase_p) else
    $error("PENABLE was not stable during \"Access Phase\"");

  // Properties and assertions for control signals stability during Access Phase
  property pwrite_stable_at_access_phase_p;
    @(posedge PCLK) disable iff(!PRESETn || !has_checks)
    access_phase_s |-> $stable(PWRITE);
  endproperty
  assert_pwrite_stable_at_access_phase: assert property(pwrite_stable_at_access_phase_p) else
    $error("PWRITE was not stable during \"Access Phase\"");

  property paddr_stable_at_access_phase_p;
    @(posedge PCLK) disable iff(!PRESETn || !has_checks)
    access_phase_s |-> $stable(PADDR);
  endproperty
  assert_paddr_stable_at_access_phase: assert property(paddr_stable_at_access_phase_p) else
    $error("PADDR was not stable during \"Access Phase\"");

  property pwdata_stable_at_access_phase_p;
    @(posedge PCLK) disable iff(!PRESETn || !has_checks)
    access_phase_s and (PWRITE == 1) |-> $stable(PWDATA);
  endproperty
  assert_pwdata_stable_at_access_phase: assert property(pwdata_stable_at_access_phase_p) else
    $error("PWDATA was not stable during \"Access Phase\"");

  // 4. Alignment checking: PSLVERR must be asserted if address is not 4-byte aligned (last 2 bits != 2'b00)
  property p_pslverr_alignment;
    @(posedge PCLK) disable iff (!PRESETn || !has_checks)
    PSEL && PENABLE && (PADDR[1:0] != 2'b00) |-> PSLVERR == 1'b1;
  endproperty
  assert_pslverr_alignment: assert property(p_pslverr_alignment) else
    $error("PSLVERR not asserted when address is unaligned");

  // Unknown value checking properties when PSEL is active
  property unknown_value_psel_p;
    @(posedge PCLK) disable iff(!PRESETn || !has_checks)
    $isunknown(PSEL) == 0;
  endproperty
  UNKNOWN_VALUE_PSEL_A : assert property(unknown_value_psel_p) else
    $error("Detected unknown value for APB signal PSEL");

  property unknown_value_penable_p;
    @(posedge PCLK) disable iff(!PRESETn || !has_checks)
    PSEL == 1 |-> $isunknown(PENABLE) == 0;
  endproperty
  UNKNOWN_VALUE_PENABLE_A : assert property(unknown_value_penable_p) else
    $error("Detected unknown value for APB signal PENABLE");

  property unknown_value_pwrite_p;
    @(posedge PCLK) disable iff(!PRESETn || !has_checks)
    PSEL == 1 |-> $isunknown(PWRITE) == 0;
  endproperty
  UNKNOWN_VALUE_PWRITE_A : assert property(unknown_value_pwrite_p) else
    $error("Detected unknown value for APB signal PWRITE");

  property unknown_value_paddr_p;
    @(posedge PCLK) disable iff(!PRESETn || !has_checks)
    PSEL == 1 |-> $isunknown(PADDR) == 0;
  endproperty
  UNKNOWN_VALUE_PADDR_A : assert property(unknown_value_paddr_p) else
    $error("Detected unknown value for APB signal PADDR");

  property unknown_value_pwdata_p;
    @(posedge PCLK) disable iff(!PRESETn || !has_checks)
    PSEL == 1 && PWRITE == 1 |-> $isunknown(PWDATA) == 0;
  endproperty
  UNKNOWN_VALUE_PWDATA_A : assert property(unknown_value_pwdata_p) else
    $error("Detected unknown value for APB signal PWDATA");

  property unknown_value_prdata_p;
    @(posedge PCLK) disable iff(!PRESETn || !has_checks)
    PSEL == 1 && PWRITE == 0 && PREADY == 1 && PSLVERR == 0 |-> $isunknown(PRDATA) == 0;
  endproperty
  UNKNOWN_VALUE_PRDATA_A : assert property(unknown_value_prdata_p) else
    $error("Detected unknown value for APB signal PRDATA");

  property unknown_value_pready_p;
    @(posedge PCLK) disable iff(!PRESETn || !has_checks)
    PSEL == 1 |-> $isunknown(PREADY) == 0;
  endproperty
  UNKNOWN_VALUE_PREADY_A : assert property(unknown_value_pready_p) else
    $error("Detected unknown value for APB signal PREADY");

  property unknown_value_pslverr_p;
    @(posedge PCLK) disable iff(!PRESETn || !has_checks)
    PSEL == 1 && PREADY == 1 |-> $isunknown(PSLVERR) == 0;
  endproperty
  UNKNOWN_VALUE_PSLVERR_A : assert property(unknown_value_pslverr_p) else
    $error("Detected unknown value for APB signal PSLVERR");

  // Cover properties to report assertion hits in coverage reports
  cover_penable_at_setup_phase:      cover property(penable_at_setup_phase_p);
  cover_penable_entering_access_phase: cover property(penable_entering_access_phase_p);
  cover_penable_exiting_access_phase:  cover property(penable_exiting_access_phase_p);
  cover_penable_stable_at_access_phase: cover property(penable_stable_at_access_phase_p);
  cover_pwrite_stable_at_access_phase:  cover property(pwrite_stable_at_access_phase_p);
  cover_paddr_stable_at_access_phase:   cover property(paddr_stable_at_access_phase_p);
  cover_pwdata_stable_at_access_phase:  cover property(pwdata_stable_at_access_phase_p);
  cover_pslverr_alignment:              cover property(p_pslverr_alignment);

endinterface
