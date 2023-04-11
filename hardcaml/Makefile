
default:
	opam exec dune build

main:
	opam exec dune exec ./main.exe

clean:
	opam exec dune $@
	rm -f main.v

utop:
	opam exec dune $@

.PHONY: default main clean
