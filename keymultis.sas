/*
QA macro for determining if a key in a dataset has multiple distinct values
of other (nonchained) variables.
- DS is the input dataset.
- Key is the space-separated list of key variables.
- Vars is the list of variables to check for distinctness over the keys.
  All nonkeys are checked if left blank.
- OutDS is the dataset to which to report those keys not having a single
  distinct value for the checked variables. If left blank, the macro prints
  the first ten records to the screen.

The macro may create temporary dataset Z_KeyMultis in WORK.

Example call:
  %KeyMultis(WAREHOUSE.WC2006BB_A_20060630, CB_UID, PC_CB_UID, OutDS = Z);
*/
%macro KeyMultis(DS, Key, Vars =, OutDS = );
%if (&Vars = )
  %then
    %do;
      proc contents data = &DS out = Z_KeyMultis(keep = Name)
        noprint nodetails;
      quit;
      run;
      proc sql noprint;
      select Name into :Names separated by " "
        from Z_KeyMultis
        where not index("&Key", Name);
      quit;
      run;
      proc delete data = Z_KeyMultis; run;
    %end;
  %else
    %do;
      %local Names;
      %let Names = &Vars;
    %end;

%local Pos Curr SelectString HavingString;
%let Pos = 1;
%let Curr = %scan(&Names, &Pos);
%do %while(&Curr ~= );
  %if (&Pos ~= 1) %then %let SelectString = &SelectString,;
  %let SelectString = &SelectString count(distinct &Curr) as N_&Curr;
  %if (&Pos ~= 1) %then %let HavingString = &HavingString or ;
  %let HavingString = &HavingString N_&Curr > 1;
  %let Pos = %eval(&Pos + 1);
  %let Curr = %scan(&Names, &Pos);
%end;

proc sql %if (&OutDS = ) %then outobs = 10;;
%if (&OutDS ~= ) %then create table &OutDS as;
select %Separate(&Key), &SelectString
  from &DS
  group by %Separate(&Key)
  having &HavingString
  order by %Separate(&Key);
quit;
run;
%mend;
