usa_usonic3  : usa_usonic3.c st_lib.o st_lib.h
	gcc -o../bin/usa_usonic3 usa_usonic3.c st_lib.o -lrt -lpthread -lm libiniparser.a

usa_usa1  : usa_usa1.c st_lib.o st_lib.h
	gcc -o../bin/usa_usa1 usa_usa1.c st_lib.o -lrt -lpthread -lm libiniparser.a

usa_2d  : usa_2d.c st_lib.o st_lib.h
	gcc -o../bin/usa_2d usa_2d.c st_lib.o -lrt -lpthread -lm libiniparser.a

st_lib.o : st_lib.c
	gcc -c st_lib.c

proc2d : proc2d.f90 soniclib.o calendar.o
	gfortran -static -o../bin/proc2d proc2d.f90 soniclib.o calendar.o
	
eddy_cov : eddy_cov.f90 soniclib.o calendar.o
	gfortran -static -o../bin/eddy_cov eddy_cov.f90 soniclib.o calendar.o
	
calendar.o : calendar.f90
	gfortran -c -ocalendar.o calendar.f90

soniclib.o : soniclib.f90
	gfortran -c -osoniclib.o soniclib.f90

clean :
	rm *.o
	rm *.mod
	
