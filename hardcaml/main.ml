open Hardcaml

type counter =
  { counter : Signal.t option
  ; last_cycle_trigger : Signal.t
  ; halfway_trigger : Signal.t
  }

let trigger_of_cycles ~clock ~clear ~cycles_per_trigger ~active =
  let open Signal in
  assert (cycles_per_trigger > 2);
  let spec = Reg_spec.create ~clock ~clear () in
  let cycle_cnt = wire (Base.Int.ceil_log2 cycles_per_trigger) in
  let max_cycle_cnt = (cycles_per_trigger - 1) in
  let next =
    mux2 (~:active |: (cycle_cnt ==:. max_cycle_cnt))
      (zero (width cycle_cnt))
      (cycle_cnt +:. 1)
  in
  cycle_cnt <== reg spec ~enable:vdd next;
  { counter = Some cycle_cnt
  ; last_cycle_trigger =
      active &: (cycle_cnt ==:. max_cycle_cnt)
  ; halfway_trigger =
      active &: (cycle_cnt ==:. (cycles_per_trigger / 2))
  }
;;

let counter ~clock ~trigger ~minimum ~maximum =
  let open Signal in
  assert (minimum <= maximum);
  let spec = Reg_spec.create ~clock () in
  let width = Signal.num_bits_to_represent maximum in
  let range = maximum - minimum + 1 in
  if range = 1 then (
    Signal.of_int ~width maximum
  ) else (
    let ctr_next = wire (Base.Int.ceil_log2 range) in
    let ctr = reg ~enable:trigger spec ctr_next in
    ctr_next <== (
      mux2 (ctr ==:. (range - 1))
        (zero (Signal.width ctr_next))
        (ctr +:. 1)
    );
    (Signal.uresize ctr width) +:. minimum
  )
;;

let scope = Scope.create ()

let output_mode = Rtl.Output_mode.To_file("main.v")

let circuit =
  let clock = Signal.input "clk" 1 in
  let trigger = Signal.input "trigger" 1 in
  let cnt = counter ~clock ~trigger ~minimum:0 ~maximum:10 in
  Circuit.create_exn ~name:"test" [
  Signal.output "b" (Signal.input "a" 1);
  Signal.output "counter" cnt
]

let test =
  let trigger = Signal.input "trigger" 1 in
  let clock = Signal.input "clock" 1 in
  let cnt = counter ~clock ~trigger ~minimum:5 ~maximum:10 in
  let circuit = Circuit.create_exn ~name:"tx_state_machine" [ Signal.output "count" cnt ] in
  let waves, sim = Hardcaml_waveterm.Waveform.create (Cyclesim.create circuit) in
  Cyclesim.cycle sim;
  Cyclesim.cycle sim;
  (Cyclesim.in_port sim "trigger") := Bits.vdd;
  for _ = 0 to 10 do
    Cyclesim.cycle sim;
  done;
  Hardcaml_waveterm.Waveform.print ~display_height:20 ~display_width:80 ~wave_width:1 waves

;;

let () = Rtl.output ~output_mode ~database:(Scope.circuit_database scope) Verilog circuit
