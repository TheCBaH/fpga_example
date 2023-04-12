open Hardcaml

type counter = {
  counter : Signal.t option;
  last_cycle_trigger : Signal.t;
  halfway_trigger : Signal.t;
}

let trigger_of_cycles ~clock ~clear ~cycles_per_trigger ~active =
  let open Signal in
  assert (cycles_per_trigger > 2);
  let spec = Reg_spec.create ~clock ~clear () in
  let cycle_cnt = wire (Base.Int.ceil_log2 cycles_per_trigger) in
  let max_cycle_cnt = cycles_per_trigger - 1 in
  let next =
    mux2
      (~:active |: (cycle_cnt ==:. max_cycle_cnt))
      (zero (width cycle_cnt))
      (cycle_cnt +:. 1)
  in
  cycle_cnt <== reg spec ~enable:vdd next;
  {
    counter = Some cycle_cnt;
    last_cycle_trigger = active &: (cycle_cnt ==:. max_cycle_cnt);
    halfway_trigger = active &: (cycle_cnt ==:. cycles_per_trigger / 2);
  }

let counter ~clock ~trigger ~minimum ~maximum =
  let open Signal in
  assert (minimum <= maximum);
  let spec = Reg_spec.create ~clock () in
  let width = Signal.num_bits_to_represent maximum in
  let range = maximum - minimum + 1 in
  if range = 1 then Signal.of_int ~width maximum
  else
    let ctr_next = wire (Base.Int.ceil_log2 range) in
    let ctr = reg ~enable:trigger spec ctr_next in
    ctr_next
    <== mux2 (ctr ==:. range - 1) (zero (Signal.width ctr_next)) (ctr +:. 1);
    Signal.uresize ctr width +:. minimum

let counter_with_carry ?(base = 10) ?(bits = 4) ~reset ~increment ~clock () =
  let base_bits = Base.Int.ceil_log2 base in
  assert (bits >= base_bits);
  let spec = Reg_spec.create ~clock () in
  let open Signal in
  let count_next = wire bits in
  let limit = base - 1 in
  let count = reg spec count_next in
  let cary = increment &: (count ==:. limit) in
  count_next
  <== mux2 (cary |: reset)
        (zero (Signal.width count_next))
        (mux2 increment (count +:. 1) count);
  (count, cary)

let counter_with_carry_test_1 =
  let _clock = "clock" in
  let _increment = "increment" in
  let _reset = "[reset]" in
  let clock = Signal.input _clock 1 in
  let increment = Signal.input _increment 1 in
  let reset = Signal.input _reset 1 in
  let count, carry = counter_with_carry ~increment ~reset ~base:5 ~bits:3 ~clock () in
  let circuit =
    Circuit.create_exn ~name:"counter_with_carry"
      [ Signal.output "carry" carry; Signal.output "count" count ]
  in
  let waves, sim =
    Hardcaml_waveterm.Waveform.create (Cyclesim.create circuit)
  in
  let cycles n =
    for _ = 0 to n do
      Cyclesim.cycle sim
    done
  in
  cycles 2;
  Cyclesim.in_port sim _increment := Bits.vdd;
  cycles 5;
  Cyclesim.in_port sim _increment := Bits.gnd;
  cycles 3;
  Cyclesim.in_port sim _increment := Bits.vdd;
  cycles 7;
  Cyclesim.in_port sim _increment := Bits.gnd;
  cycles 1;
  Cyclesim.in_port sim _increment := Bits.vdd;
  cycles 2;
  Cyclesim.in_port sim _reset := Bits.vdd;
  cycles 4;
  Cyclesim.in_port sim _reset := Bits.gnd;
  cycles 7;
  Hardcaml_waveterm.Waveform.print ~display_height:14 ~display_width:100
    ~wave_width:0 waves

let counter_with_carry_test_2 =
  let _clock = "clock" in
  let _increment = "increment" in
  let _reset = "[reset]" in
  let clock = Signal.input _clock 1 in
  let increment = Signal.input _increment 1 in
  let reset = Signal.input _reset 1 in
  let count0, carry0 = counter_with_carry ~increment ~reset ~clock () in
  let count1, _ = counter_with_carry ~increment:carry0 ~reset ~clock () in
  let circuit =
    Circuit.create_exn ~name:"counter_with_carry"
      [
        Signal.output "carry0" carry0;
        Signal.output "count0" count0;
        Signal.output "count1" count1;
      ]
  in
  let waves, sim =
    Hardcaml_waveterm.Waveform.create (Cyclesim.create circuit)
  in
  let set wire = Cyclesim.in_port sim wire := Bits.vdd in
  let clear wire = Cyclesim.in_port sim wire := Bits.gnd in
  let cycles n =
    for _ = 0 to n do
      Cyclesim.cycle sim
    done
  in
  cycles 2;
  set _increment;
  cycles 5;
  clear _increment;
  cycles 3;
  set _increment;
  cycles 12;
  clear _increment;
  cycles 1;
  set _increment;
  cycles 2;
  set _reset;
  cycles 4;
  clear _reset;
  cycles 2;
  Hardcaml_waveterm.Waveform.print ~display_height:16 ~display_width:100
    ~wave_width:0 waves

type clock = {
  clock: int;
  wire: Signal.t;
}

let clock_gen ~target ~reset ~clock () =
  let divider = clock.clock / target in
  let limit = divider - 1 in
  let bits = Base.Int.ceil_log2 divider in
  print_endline (string_of_int limit);
  print_endline (string_of_int bits);
  let open Signal in
  let spec = Reg_spec.create ~clock:clock.wire ~clear:reset () in
  let count_next = wire bits in
  let count = reg spec count_next in
  let pulse = count ==:. limit in
  count_next <== mux2 pulse
      (zero bits)
      (count +:. 1);
  (pulse,count)
;;
let clock_gen_test =
  let _clock = "clock" in
  let _reset = "[reset]" in
  let clock = {
    clock=10;
    wire=Signal.input _clock 1;
  } in
  let reset = Signal.input _reset 1 in
  let pulse = clock_gen ~clock ~reset ~target:2 () in
  let circuit =
    Circuit.create_exn ~name:"clock_gen"
      [
        Signal.output "pulse" (fst pulse);
        Signal.output "count" (snd pulse);
      ]
  in
  let waves, sim =
    Hardcaml_waveterm.Waveform.create (Cyclesim.create circuit)
  in
  let set wire = Cyclesim.in_port sim wire := Bits.vdd in
  let clear wire = Cyclesim.in_port sim wire := Bits.gnd in
  let cycles n =
    for _ = 0 to n do
      Cyclesim.cycle sim
    done in
  cycles 10;
  set _reset;
  cycles 2;
  clear _reset;
  cycles 10;
  Hardcaml_waveterm.Waveform.print ~display_height:14 ~display_width:80
    ~wave_width:0 waves


let scope = Scope.create ()

let output_mode = Rtl.Output_mode.To_file "main.v"

let circuit =
  let clock = Signal.input "clk" 1 in
  let trigger = Signal.input "trigger" 1 in
  let cnt = counter ~clock ~trigger ~minimum:0 ~maximum:10 in
  Circuit.create_exn ~name:"test"
    [ Signal.output "b" (Signal.input "a" 1); Signal.output "counter" cnt ]

let test =
  let trigger = Signal.input "trigger" 1 in
  let clock = Signal.input "clock" 1 in
  let cnt = counter ~clock ~trigger ~minimum:5 ~maximum:10 in
  let circuit =
    Circuit.create_exn ~name:"tx_state_machine" [ Signal.output "count" cnt ]
  in
  let waves, sim =
    Hardcaml_waveterm.Waveform.create (Cyclesim.create circuit)
  in
  Cyclesim.cycle sim;
  Cyclesim.cycle sim;
  Cyclesim.in_port sim "trigger" := Bits.vdd;
  for _ = 0 to 10 do
    Cyclesim.cycle sim
  done;
  Hardcaml_waveterm.Waveform.print ~display_height:10 ~display_width:80
    ~wave_width:1 waves

let () =
  Rtl.output ~output_mode
    ~database:(Scope.circuit_database scope)
    Verilog circuit
