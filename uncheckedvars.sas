/*
This macro is intended for use in QA routines. It prints a list of variables
in the COMP dataset that are not in the BASE dataset. No regard is given to
the datatype--so long as the names are in both datasets, no printing occurs.
Thus, the macro is meant as a supplement to PROC COMPARE.
*/
%macro UncheckedVars(Base, Comp);
%local TabNames NameBase NameComp;
%let TabNames = %GetNewDSNames(NumNames = 2);
%let NameBase = %scan(&TabNames, 1);
%let NameComp = %scan(&TabNames, 2);
proc contents data = &Base out = &NameBase(keep = Name)
  nodetails noprint;
run;
proc contents data = &Comp out = &NameComp(keep = Name)
  nodetails noprint;
run;
proc sql;
select upcase(Name) from &NameComp except
  select upcase(Name) from &NameBase;
quit;
run;
proc delete data = &NameComp &NameBase; run;
%mend;
