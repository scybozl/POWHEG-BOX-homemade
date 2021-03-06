#-*- Makefile -*-
## Choose compiler: gfortran,ifort (g77 not supported, F90 constructs in use!)
COMPILER=gfortran
FC=$(COMPILER)
## Choose PDF: native,lhapdf
## LHAPDF package has to be installed separately
PDF=lhapdf
#Choose Analysis: dummy, process specific
## default analysis may require FASTJET package, that has to be installed separately (see below)
ANALYSIS=dummy
## For static linking uncomment the following
#STATIC= -static
#

OBJ=obj-$(COMPILER)
OBJDIR:=$(OBJ)

ifeq ("$(COMPILER)","gfortran")	
F77=gfortran -ffree-line-length-0 -fno-automatic -J$(OBJ) -I$(OBJ)
## -fbounds-check sometimes causes a weird error due to non-lazy evaluation
## of boolean in gfortran.
#FFLAGS= -Wall -Wimplicit-interface -fbounds-check
## For floating point exception trapping  uncomment the following 
#FPE=-ffpe-trap=invalid,zero,overflow,underflow 
## gfortran 4.4.1 optimized with -O3 yields erroneous results
## Use  to be on the safe side
OPT=
## For debugging uncomment the following
#DEBUG= -ggdb 
ifdef DEBUG
OPT=-O0
FPE=-ffpe-trap=invalid,zero,overflow
#,underflow
endif
endif

ifeq ("$(COMPILER)","ifort")
F77 = ifort -save  -extend_source  -module $(OBJ)
#CXX = g++
#LIBS = -limf
#FFLAGS =  -checkm
## For floating point exception trapping  uncomment the following 
#FPE = -fpe0
OPT = -O3 #-fast
## For debugging uncomment the following
#DEBUG= -debug -g
ifdef DEBUG
OPT=-O0 
FPE = -fpe0
endif
endif

GOSAMLIBS=$(shell cd GoSamlib ; echo *.f *.f90 ' ' | sed 's/qlonshellcutoff.f// ; s/qlconstants.f// ; s/.f /.o /g ; s/.f90 /.o /g ; ' | tee GoSamlib.txt)
GOSAMLIBS+=$(shell cd GoSamlib ; echo *.cc *.F90 ' ' | sed 's/.cc /.o /g ; s/.F90 /.o /g ; ' | tee GoSamlib.txt)

PWD=$(shell pwd)
WDNAME=$(shell basename $(PWD))
VPATH= ./:../:$(OBJDIR):./GoSamlib/

INCLUDE0=$(PWD)
INCLUDE1=$(PWD)/include
INCLUDE2=$(shell dirname $(PWD))/include
FF=$(F77) $(FFLAGS) $(FPE) $(OPT) $(DEBUG) -I$(INCLUDE0) -I$(INCLUDE1) -I$(INCLUDE2)

INCLUDE =$(wildcard ../include/*.h *.h include/*.h)

ifeq ("$(PDF)","lhapdf")
LHAPDF_CONFIG=lhapdf-config
FJCXXFLAGS+= $(shell $(LHAPDF_CONFIG) --cxxflags)
PDFPACK=lhapdf6if.o lhapdf6ifcc.o
LIBSLHAPDF= -Wl,-rpath,$(shell $(LHAPDF_CONFIG) --libdir)  -L$(shell $(LHAPDF_CONFIG) --libdir) -lLHAPDF -lstdc++
ifeq  ("$(STATIC)","-static") 
## If LHAPDF has been compiled with gfortran and you want to link it statically, you have to include
## libgfortran as well. The same holds for libstdc++. 
## One possible solution is to use fastjet, since $(shell $(FASTJET_CONFIG) --libs --plugins ) -lstdc++
## does perform this inclusion. The path has to be set by the user. 
# LIBGFORTRANPATH= #/usr/lib/gcc/x86_64-redhat-linux/4.1.2
# LIBSTDCPP=/lib64
LIBSLHAPDF+=  -L$(LIBGFORTRANPATH)  -lgfortranbegin -lgfortran -L$(LIBSTDCPP) -lstdc++
endif
LIBS+=$(LIBSLHAPDF)
else
PDFPACK=mlmpdfif.o hvqpdfpho.o
endif


ifeq ("$(ANALYSIS)","YOURPROCESS")
##To include Fastjet configuration uncomment the following lines. 
FASTJET_CONFIG=$(shell which fastjet-config)
LIBSFASTJET += $(shell $(FASTJET_CONFIG) --libs --plugins ) -lstdc++
FJCXXFLAGS+= $(shell $(FASTJET_CONFIG) --cxxflags)
PWHGANAL=pwhg_bookhist-multi.o pwhg_analysis.o
## Also add required Fastjet drivers to PWHGANAL (examples are reported)
#PWHGANAL+= fastjetsisconewrap.o fastjetktwrap.o fastjetCDFMidPointwrap.o fastjetD0RunIIConewrap.o fastjetfortran.o
#PWHGANAL+= fastjetsisconewrap.o fastjetktwrap.o fastjetfortran.o
PWHGANAL+=  fastjetfortran.o
else
PWHGANAL=pwhg_bookhist-multi.o pwhg_analysis-dummy.o
endif

NINJAFLAGS=-DHAVE_CONFIG_H -I./GoSamlib -I./GoSamlib/ninja  -fcx-limited-range

%.o: %.f $(INCLUDE) | $(OBJDIR)
	$(FF) -c -o $(OBJ)/$@ $<

%.o: %.f90 $(INCLUDE) | $(OBJDIR)
	$(FF) -c -o $(OBJ)/$@ $<

%.o: %.F90 $(INCLUDE) | $(OBJDIR)
	$(FF) -c -o $(OBJ)/$@ $<

%.o: %.c | $(OBJDIR)
	$(CC) $(DEBUG) -c -o $(OBJ)/$@ $^ 

%.o: %.cc | $(OBJDIR)
	$(CXX) $(DEBUG) -c -o $(OBJ)/$@ $^ $(NINJAFLAGS) $(FJCXXFLAGS)
LIBS+=-lz
USER=init_couplings.o init_processes.o Born_phsp.o Born.o virtual.o	\
     real.o  $(PWHGANAL) phi1_2.o phi3m0.o breit.o boost.o


PWHG=pwhg_main.o pwhg_init.o bbinit.o btilde.o lhefwrite.o		\
	LesHouches.o LesHouchesreg.o gen_Born_phsp.o find_regions.o	\
	test_Sudakov.o pt2maxreg.o sigborn.o gen_real_phsp.o maxrat.o	\
	gen_index.o gen_radiation.o Bornzerodamp.o sigremnants.o	\
	random.o boostrot.o bra_ket_subroutines.o cernroutines.o	\
	init_phys.o powheginput.o pdfcalls.o sigreal.o sigcollremn.o	\
	pwhg_analysis_driver.o checkmomzero.o		                \
	setstrongcoupl.o integrator.o newunit.o mwarn.o sigsoftvirt.o	\
	reshufflemoms.o pwhg_gosam.o                                    \
	sigcollsoft.o sigvirtual.o  ubprojections.o                     \
	pwhgreweight.o setlocalscales.o mint_upb.o opencount.o          \
	validflav.o $(PDFPACK) $(USER) $(FPEOBJ) lhefread.o pwhg_io_interface.o rwl_weightlists.o rwl_setup_param_weights.o

LIBDIRMG=$(OBJ)
LINKMGLIBS =  -L$(LIBDIRMG)  -lmadgraph -lmodel -ldhelas3 

MADLIBS=libdhelas3.a libmadgraph.a libmodel.a

# Get SVN info for SVN version stamping code
$(shell ../svnversion/svnversion.sh>/dev/null)

# target to generate LHEF output
pwhg_main:gosamlib.a $(PWHG) $(MADLIBS)
	$(FF) $(patsubst %,$(OBJ)/%,$(PWHG)) $(LINKMGLIBS) $(LIBS) $(LIBSFASTJET) $(STATIC)  $(OBJ)/gosamlib.a -o $@ -lstdc++

gosamlib.a: $(GOSAMLIBS)
	\rm $(OBJ)/gosamlib.a ; $(PWD)/GoSamlib/compile_gosamlib.sh $(PWD)/$(OBJ)

LHEF=lhef_analysis.o boostrot.o random.o cernroutines.o		\
     opencount.o powheginput.o $(PWHGANAL)	\
     lhefread.o pwhg_io_interface.o rwl_weightlists.o newunit.o pwhg_analysis_driver.o $(FPEOBJ)

# target to analyze LHEF output
lhef_analysis:$(LHEF)
	$(FF) $(patsubst %,$(OBJ)/%,$(LHEF)) $(LIBS) $(LIBSFASTJET) $(STATIC)  -o $@ 



# target to read event file, shower events with HERWIG + analysis
HERWIG=main-HERWIG.o setup-HERWIG-lhef.o herwig.o boostrot.o	\
	powheginput.o $(PWHGANAL) lhefread.o pwhg_io_interface.o rwl_weightlists.o	\
	pdfdummies.o opencount.o $(FPEOBJ) 

main-HERWIG-lhef: $(HERWIG)
	$(FF) $(patsubst %,$(OBJ)/%,$(HERWIG))  $(LIBSFASTJET)  $(STATIC) -o $@

# target to read event file, shower events with PYTHIA + analysis
PYTHIA=main-PYTHIA.o setup-PYTHIA-lhef.o pythia.o boostrot.o powheginput.o \
	$(PWHGANAL) lhefread.o pwhg_io_interface.o rwl_weightlists.o newunit.o 	\
	pwhg_analysis_driver.o random.o cernroutines.o opencount.o	\
	$(FPEOBJ)

main-PYTHIA-lhef: $(PYTHIA)
	$(FF) $(patsubst %,$(OBJ)/%,$(PYTHIA)) $(LIBS) $(LIBSFASTJET)  $(STATIC) -o $@

# target to cleanup
.PHONY: clean libdhelas3.a libmadgraph.a libmodel.a

XFFLAGS=$(DEBUG) $(OPT)
libdhelas3.a:
	cd DHELAS ; make -j FC="$(F77)" F77="$(F77)" XFFLAGS="$(XFFLAGS)" OBJ="$(OBJ)"

libmadgraph.a:
	cd Madlib ; make -j FC="$(F77)" F77="$(F77)" XFFLAGS"=$(XFFLAGS)" OBJ="$(OBJ)"

ifeq ("$(COMPILER)","gfortran")
XFFLAGS +=-ffixed-line-length-132
else
XFFLAGS +=-extend-source
endif

libmodel.a:
	cd MODEL ; make -j FC="$(F77)" F77="$(F77)" XFFLAGS="$(XFFLAGS)" OBJ="$(OBJ)"


clean:
	rm -f $(patsubst %,$(OBJ)/%,$(USER) $(PWHG) $(LHEF) $(HERWIG) $(PYTHIA)) pwhg_main lhef_analysis main-HERWIG-lhef	\
	main-PYTHIA-lhef


veryclean:
	rm -f $(OBJ)/*.o $(OBJ)/*.mod $(OBJ)/*.a pwhg_main lhef_analysis main-HERWIG-lhef	\
	main-PYTHIA-lhef *.a DHELAS/*.o Madlib/*.o MODEL/*.o GoSamlib.lst

# target to generate object directory if it does not exist
$(OBJDIR):
	mkdir -p $(OBJDIR)

##########################################################################

include GoSamlib/Makefile.virt.dep

# Dependencies of SVN version stamp code
pwhg_main.o: svn.version
lhefwrite.o: svn.version


