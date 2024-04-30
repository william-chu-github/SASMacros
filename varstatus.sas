* variation on previous macro--looks like it should be more efficient (loops
  through data only once)--but it takes more execution time ;
%macro VarStatus(CurrDS, OutDS);
%local DSID NumRecs NumVars VarName VarType SelectVars IntoVars VarList
       VarStatus;
* open DS ;
%let DSID = %sysfunc(open(&CurrDS, I));
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

%let VarName = ;
%let VarType = ;
%let SelectVars = ;
%let IntoVars = ;
%let VarList = ;

* execute for each variable ;
%do I = 1 %to &NumVars;
  %let VarName = %sysfunc(varname(&DSID, &I));
  %let VarType = %sysfunc(vartype(&DSID, &I));
  %if &I ~= 1
    %then
      %do;
        %let SelectVars = &SelectVars, count(distinct(&VarName)), nmiss(&VarName);
        %let IntoVars = &IntoVars, :Distinct&I, :NMiss&I, :NZero&I;
        %let VarList = &VarList &VarName;
      %end;
    %else
      %do;
        %let SelectVars = count(distinct(&VarName)), nmiss(&VarName);
        %let IntoVars = :Distinct&I, :NMiss&I, :NZero&I;
        %let VarList = &VarName;
      %end;
  %if &VarType = N
    %then
      %do;
        %let SelectVars = &SelectVars, 
             sum(case when(&VarName = 0) then 1 else 0 end);
      %end;
    %else
      %do;
        %let SelectVars = &SelectVars, 0;
      %end;
%end;

%local %sysfunc(translate(%quote(&IntoVars), "  ", ":,"));
select &SelectVars
  into &IntoVars
  from &CurrDS;

%do I = 1 %to &NumVars;
  %let VarName = %scan(&VarList, &I);
  %if (&NumRecs = &&NMiss&I)
    %then %let VarStatus = %str(Unpopulated);
    %else
      %do;
        %if (&&NMiss&I = 0)
          %then %let VarStatus = %str(Totally Populated);
          %else %let VarStatus = %str(Partially Populated);
      %end;
  insert into &OutDS values(
    "&VarName", "&VarStatus", &&NZero&I, &&NMiss&I, &&Distinct&I, &NumRecs
  );
%end;
quit;
run;
%let DSID = %sysfunc(close(&DSID));
%mend VarStatus;
