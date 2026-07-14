class uart_agent_config extends uvm_object;
  `uvm_object_utils(uart_agent_config)

  virtual uart_serial_if vif;
  virtual apb_if        vif_apb;
  uvm_active_passive_enum is_active = UVM_ACTIVE;

  function new(string name = "uart_agent_config");
    super.new(name);
  endfunction
endclass
