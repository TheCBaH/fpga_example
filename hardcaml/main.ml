open Hardcaml

type counter = { counter : Signal.t option; last_cycle_trigger : Signal.t; halfway_trigger : Signal.t }

let trigger_of_cycles ~clock ~clear ~cycles_per_trigger ~active =
  let open Signal in
  assert (cycles_per_trigger > 2);
  let spec = Reg_spec.create ~clock ~clear () in
  let cycle_cnt = wire (Base.Int.ceil_log2 cycles_per_trigger) in
  let max_cycle_cnt = cycles_per_trigger - 1 in
  let next = mux2 (~:active |: (cycle_cnt ==:. max_cycle_cnt)) (zero (width cycle_cnt)) (cycle_cnt +:. 1) in
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
    ctr_next <== mux2 (ctr ==:. range - 1) (zero (Signal.width ctr_next)) (ctr +:. 1);
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
  count_next <== mux2 (cary |: reset) (zero (Signal.width count_next)) (mux2 increment (count +:. 1) count);
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
    Circuit.create_exn ~name:"counter_with_carry" [ Signal.output "carry" carry; Signal.output "count" count ]
  in
  let waves, sim = Hardcaml_waveterm.Waveform.create (Cyclesim.create circuit) in
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
  Hardcaml_waveterm.Waveform.print ~display_height:14 ~display_width:100 ~wave_width:0 waves

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
      [ Signal.output "carry0" carry0; Signal.output "count0" count0; Signal.output "count1" count1 ]
  in
  let waves, sim = Hardcaml_waveterm.Waveform.create (Cyclesim.create circuit) in
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
  Hardcaml_waveterm.Waveform.print ~display_height:16 ~display_width:100 ~wave_width:0 waves

type clock = { clock : int; wire : Signal.t }

let clock_gen ~target ~reset ~clock =
  let divider = clock.clock / target in
  let limit = divider - 1 in
  let bits = Base.Int.ceil_log2 divider in
  let open Signal in
  let spec = Reg_spec.create ~clock:clock.wire ~clear:reset () in
  let count = wire bits in
  let pulse = count ==:. limit in
  let next = mux2 pulse (zero bits) (count +:. 1) in
  count <== reg spec next;
  (pulse, count)

let clock_gen_test =
  let _clock = "clock" in
  let _reset = "[reset]" in
  let clock = { clock = 10; wire = Signal.input _clock 1 } in
  let reset = Signal.input _reset 1 in
  let pulse = clock_gen ~clock ~reset ~target:2 in
  let circuit =
    Circuit.create_exn ~name:"clock_gen" [ Signal.output "pulse" (fst pulse); Signal.output "count" (snd pulse) ]
  in
  let waves, sim = Hardcaml_waveterm.Waveform.create (Cyclesim.create circuit) in
  let set wire = Cyclesim.in_port sim wire := Bits.vdd in
  let clear wire = Cyclesim.in_port sim wire := Bits.gnd in
  let cycles n =
    for _ = 0 to n do
      Cyclesim.cycle sim
    done
  in
  cycles 10;
  set _reset;
  cycles 2;
  clear _reset;
  cycles 15;
  Hardcaml_waveterm.Waveform.print ~display_height:11 ~display_width:80 ~wave_width:0 waves

let segment_encode ~digit =
  let display =
    [
      ('0', "1000000");
      ('1', "1111001");
      ('2', "0100100");
      ('3', "0110000");
      ('4', "0011001");
      ('5', "0010010");
      ('6', "0000010");
      ('7', "1111000");
      ('8', "0000000");
      ('9', "0010000");
      ('A', "0001000");
      ('b', "0000011");
      ('C', "1000110");
      ('d', "0100001");
      ('E', "0000110");
      ('F', "0001110");
    ]
  in
  let open Signal in
  let segments = mux digit (List.map (fun (_, s) -> of_string ("7'b" ^ s)) display) in
  segments

let segment_encode_test =
  let _digit = "digit" in
  let digit = Signal.input _digit 4 in
  let segments = segment_encode ~digit in
  let _segments = "segments" in
  let circuit = Circuit.create_exn ~name:"segment_encode" [ Signal.output _segments segments ] in
  let waves, sim = Hardcaml_waveterm.Waveform.create (Cyclesim.create circuit) in
  let set wire n =
    Cyclesim.in_port sim wire := Bits.of_int ~width:4 n;
    Cyclesim.cycle sim
  in
  set _digit 0;
  set _digit 1;
  set _digit 8;
  set _digit 0xb;
  set _digit 0xF;
  let display_rules = Hardcaml_waveterm.Display_rule.[ port_name_is _segments ~wave_format:Bit; default ] in
  Hardcaml_waveterm.Waveform.print ~display_rules ~display_height:11 ~display_width:80 ~wave_width:4 waves

type digit = {
  data: Signal.t;
  enable: Signal.t;
  dot: Signal.t;
}

let display ~clock ~digits ~next ~reset =
  let digits_max = List.length digits in
  let spec = Reg_spec.create ~clock ~clear:reset () in
  let open Signal in
  let digit = Base.Int.ceil_log2 digits_max |> wire in
  let anode = List.mapi (fun n d ->
    let enable = ~: (d.enable &: (digit ==:. n)) in
     wireof enable) digits |> concat_msb in
  let data = mux digit (List.map (fun d -> d.data) digits) in
  let segment = segment_encode ~digit:data in
  let dot = mux digit (List.map (fun d -> d.dot) digits) in
  let display = segment @: dot in
  let next = mux2 next
    (mux2 (digit ==:. digits_max)
      (width digit |> zero )
      (digit +:. 1)
    ) digit in
  digit <== reg spec next;
  anode,display

let display_test =
  let _digit_0 = "digit_0" in
  let _digit_1 = "digit_1" in
  let _dot = "dot" in
  let _enable = "enable" in
  let _clock = "clock" in
  let _reset = "reset" in
  let _segments = "segments" in
  let _anode = "anode" in
  let digit_0 = Signal.input _digit_0 4 in
  let digit_1 = Signal.input _digit_1 4 in
  let clock = Signal.input _clock 1 in
  let enable = Signal.input _enable 1 in
  let dot = Signal.input _dot 1 in
  let digits = [
    {data=digit_0;enable;dot};
    {data=digit_1;enable;dot};
  ] in
  let reset = Signal.input _reset 1 in
  let (anode,segments) = display ~clock ~digits ~reset ~next:enable in
  let circuit = Circuit.create_exn ~name:"display" [ Signal.output _anode anode; Signal.output _segments segments] in
  let waves, sim = Hardcaml_waveterm.Waveform.create (Cyclesim.create circuit) in
  let set wire = Cyclesim.in_port sim wire := Bits.vdd in
  (* let clear wire = Cyclesim.in_port sim wire := Bits.gnd in *)
  let cycles n =
    for _ = 0 to n do
      Cyclesim.cycle sim
    done
  in
  set _enable;
  Cyclesim.in_port sim _digit_0 := Bits.of_int ~width:4 1;
  Cyclesim.in_port sim _digit_1 := Bits.of_int ~width:4 2;
  cycles 8;
  let display_rules = Hardcaml_waveterm.Display_rule.[ port_name_is_one_of [_segments; _anode] ~wave_format:Bit; default ] in
  Hardcaml_waveterm.Waveform.print ~display_rules ~display_height:25 ~display_width:100 ~wave_width:4 waves

let scope = Scope.create ()
let output_mode = Rtl.Output_mode.To_file "main.v"

let circuit =
  let clock = Signal.input "clk" 1 in
  let trigger = Signal.input "trigger" 1 in
  let cnt = counter ~clock ~trigger ~minimum:0 ~maximum:10 in
  Circuit.create_exn ~name:"test" [ Signal.output "b" (Signal.input "a" 1); Signal.output "counter" cnt ]

let test =
  let trigger = Signal.input "trigger" 1 in
  let clock = Signal.input "clock" 1 in
  let cnt = counter ~clock ~trigger ~minimum:5 ~maximum:10 in
  let circuit = Circuit.create_exn ~name:"tx_state_machine" [ Signal.output "count" cnt ] in
  let waves, sim = Hardcaml_waveterm.Waveform.create (Cyclesim.create circuit) in
  Cyclesim.cycle sim;
  Cyclesim.cycle sim;
  Cyclesim.in_port sim "trigger" := Bits.vdd;
  for _ = 0 to 10 do
    Cyclesim.cycle sim
  done;
  Hardcaml_waveterm.Waveform.print ~display_height:10 ~display_width:80 ~wave_width:1 waves

let () = Rtl.output ~output_mode ~database:(Scope.circuit_database scope) Verilog circuit
