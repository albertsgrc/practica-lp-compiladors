all: karel

karel: karel.g
	antlr -gt karel.g && dlg parser.dlg scan.c && g++ -Wno-write-strings -std=c++1y -DNDEBUG -O2 -o karel karel.c scan.c err.c

antlrclean:
	rm -f *.c *.h *.dlg

clean: 
	rm -f *.c *.h *.dlg karel
