_build/default/src/bin/gossip.exe: 
		dune build src/bin/gossip.exe

gossip: _build/default/src/bin/gossip.exe
	sudo cp $< $@

clean: 
		rm -rf _build
		rm ./gossip

build:
	dune build src/bin/gossip.exe

rebuild: clean gossip
