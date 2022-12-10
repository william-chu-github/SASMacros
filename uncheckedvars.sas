/*
This macro is intended for use in QA routines. It prints a list of variables
in the COMP dataset that are not in the BASE dataset. No regard is given to
the datatype--so long as the names are in both datasets, no printing occurs.
Thus, the macro is meant as a supplement to PROC COMPARE.

Temporary datasets Z_UncheckedVars_NameBase and Z_UncheckedVars_NameComp
are created in WORK and deleted after execution.
*/
%macro UncheckedVars(Base, Comp);
proc contents data = &Base out = Z_UncheckedVars_NameBase(keep = Name)
  nodetails noprint;
run;
proc contents data = &Comp out = Z_UncheckedVars_NameComp(keep = Name)
  nodetails noprint;
run;
proc sql;
select upcase(Name) from Z_UncheckedVars_NameComp except
  select upcase(Name) from Z_UncheckedVars_NameBase;
quit;
run;
proc delete data = Z_UncheckedVars_NameComp Z_UncheckedVars_NameBase; run;
%mend;
