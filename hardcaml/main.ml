open Hardcaml

let scope = Scope.create ()

let output_mode = Rtl.Output_mode.To_file("main.v")

let circuit = Circuit.create_exn ~name:"test" [ Signal.output "b" (Signal.input "a" 1) ]

let () = Rtl.output ~output_mode ~database:(Scope.circuit_database scope) Verilog circuit
