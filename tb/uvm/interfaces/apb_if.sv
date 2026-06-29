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
endinterface
