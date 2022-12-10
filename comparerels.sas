/*
Compare key relationships between multiple tables for consistency.

- TABS is the first argument and should be a space-separated list of tables
  to check for consistency. Each of the tables must contain the variables
  listed in VARS.
- VARS lists the variables in the tables to check for consistency. Any
  value combination that is not in every table will be flagged as an error.

Example usage: %CompareRels(ZCB ZCOLB, COLB_UID CU_UID);

The macro prints to the OUTPUT window if an error is found. No output is given
if no inconsistencies are found.

This macro creates several temporary datasets in WORK which are deleted:
  Z_CompareRels_<number>

This macro creates a series of IN variables named
  Z_CompareRels_In_<number>
to help determine extraneous or missing relationships. In the unlikely event
that the input tables have variables named like that, the macro will probably
fail or give erroneous results.
*/
%macro CompareRels(Tabs, Vars);
%local VarsComma MergeString WordNum Word;
%let VarsComma = %Separate(&Vars);
%let MergeString = ;

%let WordNum = 1;
%let Word = %scan(&Tabs, 1, %str( ));
%do %while(&Word ~= );
  proc sql;
  create table Z_CompareRels_&WordNum as
    select distinct &VarsComma
      from &Word
      order by &VarsComma;
  quit;
  run;
  %let MergeString =
    &MergeString Z_CompareRels_&WordNum(in = Z_CompareRels_In_&WordNum);
  %let WordNum = %eval(&WordNum + 1);
  %let Word = %scan(&Tabs, &WordNum, %str( ));
%end;
%let WordNum = %eval(&WordNum - 1);
data Z_CompareRels_0;
merge &MergeString;
by &Vars;
if sum(of Z_CompareRels_In_:) ~= &WordNum;
run;
title "tables (&Tabs) have inconsistent relationships (&Vars)";
title2 "(first 10 shown)";
proc print data = Z_CompareRels_0(obs = 10) noobs; run;
title;
proc datasets nodetails nolist;
delete Z_CompareRels_:;
quit;
run;
%mend CompareRels;
