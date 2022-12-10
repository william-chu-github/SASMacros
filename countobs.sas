/* function that gets the number of observations in a dataset */
%macro CountObs(DS);
%local DSID NumObs;
%let DSID = %sysfunc(open(&DS));
%let NumObs = %sysfunc(attrn(&DSID, nlobs));
%let DSID = %sysfunc(close(&DSID));
%if (&NumObs = -1)
  %then
    %do;
      %put ERROR: %nrquote(%%)CountObs macro returned -1 (not available)... target dataset no valid for this function;
      %abort cancel;
    %end;
  %else %do; &NumObs %end;
%mend CountObs;
