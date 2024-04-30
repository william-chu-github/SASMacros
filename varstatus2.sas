* macro that counts populated values of an input dataset ;
%macro VarStatus2(CurrDS, OutDS);
%local DSID NumRecs NumVars VarName VarType VarStatus NMiss NDistinct
       NumZeros;
* open DS ;
%let DSID = %sysfunc(open(&CurrDS, i));
%if (&OutDS = ) %then %let OutDS = &CurrDS._Pop;

proc sql noprint;
* create output table ;
create table &OutDS(
  VarName character(32), VarStatus character(20),
  NumZero integer, NumMiss integer, NumUnique integer, NumRecs integer
);
* count total number of records in input file ;
select count(*) into :NumRecs from &CurrDS;
%let NumRecs = %trim(&NumRecs);
%let NumVars = %sysfunc(attrn(&DSID, nvars));
* execute for each variabe ;
%do I = 1 %to &NumVars;
  %let VarName = %sysfunc(varname(&DSID, &I));
  %let VarType = %sysfunc(vartype(&DSID, &I));
  * count missing and distinct values of variable ;
  select nmiss(&VarName), count(distinct(&VarName))
    into :NMiss, :NDistinct
    from &CurrDS;
  %if (&NMiss = 0)
    %then %let VarStatus = %str(Totally Populated);
    %else %if (&NMiss < &NumRecs)
            %then %let VarStatus = %str(Partially Populated);
            %else %let VarStatus = %str(Unpopulated);
  * for numeric variables, determine how many zero values there are ;
  * all populated does not necessarily mean some non-zero ;
  %if (&VarType = N)
    %then
      %do;
        select count(*) into :NumZeros from &CurrDS where &VarName = 0;
        %let NumZeros = %trim(&NumZeros);
        insert into &OutDS values(
          "&VarName", "&VarStatus", &NumZeros, &NMiss, &NDistinct, &NumRecs
        );
      %end;
    %else
      %do;
        insert into &OutDS values(
          "&VarName", "&VarStatus", 0, &NMiss, &NDistinct, &NumRecs
        );
      %end;
%end;
quit;
run;
%let DSID = %sysfunc(close(&DSID));
%mend VarStatus2;
