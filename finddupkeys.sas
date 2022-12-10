/*
Find duplicate keys in an input dataset.

DS -> input dataset in which to search for duplicate keys
Key -> the search key for which there should be no duplicates
OutDS -> output dataset to save keys with a count > 1
PrintObs -> number of observations to print if there are counts > 1
*/
%macro FindDupKeys(DS = _last_, Key = , OutDS = , PrintObs = 0);
%local KeyComma DSID;
%let KeyComma = %Separate(String = &Key);
%if &DS = _last_
  %then
    %do;
      %let DSID = %sysfunc(open(&DS));
      %let DS = %sysfunc(attrc(&DSID, mem));
      %let DSID = %sysfunc(close(&DSID));
    %end;
proc sql noprint;
create table &OutDS as (
  select &KeyComma, count(*) as Count
    from &DS
    group by &KeyComma
    having Count > 1
) order by &KeyComma;
quit;
run;
%if &PrintObs > 0
  %then
    %do;
      proc print data = &OutDS(obs = &PrintObs);
      run;
    %end;
%mend FindDupKeys;
