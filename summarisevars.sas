/*
Give a dataset and a list of columns to check using proc sql.
Outputs MIN/MAX/num unique/num missing for all specified variables.
Can group by a sort key.
prints results to screen.

Parameters:
DS -> SAS dataset. Default is _last_.
ColList -> list of columns in the dataset, separated by spaces.
    Checks all columns by default.
GroupBy -> grouping key: can consist of multiple columns separated
    by spaces. Default is no grouping - all records collapsed into one.
freq -> output univariate frequency counts of the listed columns,
    using the GroupBy value as the by variable. Obviously, do not
    ask for frequency counts of columns that can take on many values;
    otherwise output screen may get clogged. Multiple columns should
    be separated by spaces. Using this option requires that the file
    be sorted by the GroupBy key. By default, no columns give frequency
    output.

example usage:

data Example;
do i = 1 TO 5;
  do j = 2 TO 6 by 2;
    k = i + j;
    if mod(k,2) = 1
      then l = 1;
      else l = .;
    output;
  end;
end;
run;

* default behaviour without a ColList is to check all columns ;
%SummariseVars(DS = Example, GroupBy = i j, Freq = i j);
* uses all default parameters ;
%SummariseVars();
%SummariseVars(DS = Example, ColList = j k, GroupBy = i, Freq = j k);
*/
%macro SummariseVars(DS = _last_, ColList = , GroupBy = , Freq = );
%local GroupByComma DSID CurrentColNum Column;
%let GroupByComma = %Separate(String = &GroupBy);
%if &DS = _last_
  %then
    %do;
      %let DSID = %sysfunc(open(&DS));
      %let DS = %sysfunc(attrc(&DSID, mem));
      %let DSID = %sysfunc(close(&DSID));
    %end;
%if (&ColList = )
  %then %let ColList = %GetVarNames(DS = &DS);
options formdlim = "-"; 
%let CurrentColNum = 1;
%let Column = %scan(&ColList, &CurrentColNum);
%do %while(&Column ~= );
  /* get min, max, count of requested variables and groups */
  title "Dataset &DS: Variable Summary for &Column";
  proc sql print;
  select  %if (&GroupByComma ~= )
            %then
              %do;
                &GroupByComma,
              %end;
          min(&Column) as MinValue, max(&Column) as MaxValue,
          count(distinct(&Column)) as NumUniquevalues,
          count(&Column) as NumPopulated,
          nmiss(&Column) as NumMissing
    from &DS
    %if (&GroupBy ~= )
      %then
        %do;
          group by &GroupByComma
        %end;
    ;
  quit;
  run;
  /* advance to next variable specified */
  %let CurrentColNum = %eval(&CurrentColNum + 1);
  %let Column = %scan(&ColList, &CurrentColNum);
%end;

/* requested frequency counts using GroupBy as the by value */
%if &Freq ~= 
  %then
    %do;
      title "Frequency Counts for Selected Variables";
      proc freq data = &DS;
      %if &GroupBy ~= 
        %then
          %do;
            by &GroupBy;
          %end;
      tables &Freq /missing;
      run;
    %end;
title;
options formdlim = "";
%mend SummariseVars;
