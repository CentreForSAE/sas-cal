
/*************
  benchmark1.sas
  
  Author
  Descr: Vergleich vom Cal-Makro mit CLAN (und CALMAR)
  
**************/



/* Uebung 1*/

** Einlesen der Daten;

** NB! Bitte den Pfad aendern!;

libname dat "C:\Users\darek\Desktop\cal-beispiele\data";
options fmtsearch = (work dat.formats) nofmterr mstored sasmstore = calmar;
 

** Wie sieht die Population aus?
	
	In dieser Uebung betrachten wir zwei Untersuchungsvariablen: ef21 Brutto Monatseinkommen und 
	und die Hilfsmerkmale Wirtschaftszwweig (wzgruppe), Geschlecht (ef10) und Alter (gebildet als 2006 - Geburtsjahr (ef11)
;

** 0) Ueberpuefen, ob die Daten richtig eingelesen sind;

proc contents data = dat.vse6 varnum; run;

** 1) Bilden der Variable alter;

data vse6; ** Die Aenderungen werden in einen neuen Datensatz gespeichert, der sich in der work Bibliothek befindet;
	set dat.vse6;
	
	alter = 2006 - ef11;
run;


** 2) Graphische Darstellung;

*** proc boxplot erwartet einen sortierten Datensatz, deswegen...;
proc sort data = vse6; by wzgruppe; run;

proc boxplot data = vse6;
	plot ef21*wzgruppe;
run;


** 3) Wir ziehen eine Stichprobe vom Umfang n;

%let n = 500;

proc surveyselect
	data = vse6
	method = SRS
	sampsize = &n
	stats
	out = vse6_smpl(rename = (samplingWeight = des_gew))
	seed = 54321
	;
run;

** Berechnen des pi-Schaetzers mit proc surveymeans;

proc surveymeans
	data = vse6_smpl
	N = 60551
	mean
	;
	var ef21;
	weight des_gew;
run;

**	Berechnung des pi-Schaetzers mit CLAN;

%macro function(i, j);
	
	%tot(ef21_tot, ef21, 1);
	%tot(p_size, 1, 1);
	%div(ef21_mean, ef21_tot, p_size);
	
	%estim(ef21_tot);
%mend function;


%clan(data = vse6_smpl, npop = 60551, nresp = &n, maxrow = 1, maxcol = 1);

title "pi-Schaetzer: Mittelwert von ef21 (CLAN)";
proc print data = Dut; run;



** 4) Poststratifizierung nach wzgruppe;

proc freq data = vse6;
	table wzgruppe /out = wzgruppe_tbl;
run;


data clan_aux_input;
	length Var $ 32.;
	input Var $ n MAR1 MAR2 MAR3 MAR4 MAR5 MAR6 MAR7 MAR8 MAR9 MAR10;
	
	datalines;
	wzgruppe 10 3043 14071 1459 2190 4887 1188 5996 2208 15668 9841
	;
run;


%interaction(var_lst = gender cohort, newvar = gender_cohort1, dat = sample, newdat=sample, fmtname = gc, fmtlib = work, type = clan)

data clan_aux_input;
length Var $ 32.;
infile datalines missover;
input VAR $ n MAR1 MAR2 MAR3 MAR4 MAR5 MAR6 MAR7 MAR8 MAR9 MAR10 MAR11 MAR12;
datalines;
gender_cohort1 12 331 1320 1892 2318 1208 77 156 1033 1689 1822 1177 96 
marital_status 4 8591 3123 214 1191
;
run;

proc freq data = sample;
  format _all_;
  tables gender_cohort1 /missing;
run;



%macro function(i, j);
	%auxvar(datax = clan_aux_input,wkout=wvikt, datawkut=sample, ident=PID);
	%greg(earnings_tot_reg, earnings, 1);
	%tot(earnings_tot, earnings, 1);
	*%tot(p_size, 1, 1);
	
	*%div(earnings_mean, ef21_tot, p_size);
	*%div(earnings_mean_reg, ef21_tot_reg, p_size);	
	
	*%estim(earnings_tot);
	%estim(earnings_tot_reg);
%mend function;

%clan(data = sample, npop = 13119, nresp = 1000, maxrow = 1, maxcol = 1);
*%clan(data = vse6_smpl, npop = 60551, nresp = &n, maxrow = 1, maxcol = 1);


proc compare base = sample(rename=(wvikt=col1)) compare = weight;
  var col1;
  run;




title "GREG-Schaetzer: Mittelwert ef21 (CLAN)";
proc print data = Dut; run;


** 4) Wir betrachten die Tabelle wzgruppe*geschlecht und moechten die gemeinsame Verteilung schaetzen.;

** Mit proc surveymeans;

data vse6_smpl;
	set vse6_smpl;
	
	unit = 1;
run;

** 	Im folgenden ist wichtig, das domain statement zu verwenden, 
		damit richtige Standardfehler ausgegeben werden;

proc surveymeans
	data = vse6_smpl
	N = 60551
	sum
	;
	var unit;
	weight des_gew;
	domain wzgruppe*ef10
	;
run;

** Das folgende ist FALSCH! Beachte die Warnung, die im SAS log ausgegeben wird;

proc sort data = vse6_smpl; by wzgruppe ef10; run;

proc surveymeans
	data = vse6_smpl
	N = 60551
	sum
	;
	var unit;
	weight des_gew;
	by wzgruppe ef10;
run;


** Mit CLAN97;

%macro function(i, j);

	%tot(freq_ij, 1, wzgruppe = &i and ef10 = &j);
	%estim(freq_ij);

%mend function;


%clan(data = vse6_smpl, npop = 60551, nresp = &n, maxrow = 10, maxcol = 2);

proc print data = Dut; run;

** Mit Randanpassung (Kalibration auf die Randverteilungen von wzgruppe und ef10);

** Das Macro gregeri befindet erstellt den Datensatz mit den Randhaeufigkeiten, der in CLAN verwendet wird;

%gregeri(formula = ~ wzgruppe + ef10, sframe = vse6, aux_out_file = CLAN_IN_wzgruppe_ef10);

%macro function(i, j);
	%auxvar(datax = Clan_in_wzgruppe_ef10);
	
	%tot(freq_ij, 1, wzgruppe = &i and ef10 = &j);
	

	%greg(freq_ij_reg, 1, wzgruppe = &i and ef10 = &j);
	
	%estim(freq_ij);
	%estim(freq_ij_reg);
%mend function;


%clan(data = vse6_smpl, npop = 60551, nresp = &n, maxrow = 10, maxcol = 2);

proc print data = Dut; run;
