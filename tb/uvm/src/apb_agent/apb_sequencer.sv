`ifndef APB_SEQUENCER_SV
`define APB_SEQUENCER_SV

class apb_sequencer extends uvm_sequencer #(apb_seq_item) implements apb_reset_handler;
  `uvm_component_utils(apb_sequencer)

  function new(string name = "apb_sequencer", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void handle_reset(uvm_phase phase);
    int objections_count;
    
    stop_sequences();
    
    objections_count = uvm_test_done.get_objection_count(this);
    if (objections_count > 0) begin
      uvm_test_done.drop_objection(this, $sformatf("Dropping %0d objections at reset", objections_count), objections_count);
    end

    start_phase_sequence(phase);
  endfunction
endclass

`endif // APB_SEQUENCER_SV
