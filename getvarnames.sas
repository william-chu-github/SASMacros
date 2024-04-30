/*
Generates the complete list of column names in a SAS dataset and
"executes" it as a macro string.
i.e., this macro is a function whose return value is the string
of the dataset's column names separated by spaces 
*/
%macro GetVarNames(DS);
%local VarList CurrentVar DSID;
%let DSID = %sysfunc(open(&DS));
%let NumVars = %sysfunc(attrn(&DSID, nvars));

/* loop through all variables and get their names */
%let CurrentVar = 1;
%do %while(&CurrentVar <= &NumVars);
  %let VarList = &VarList %sysfunc(varname(&DSID, &CurrentVar));
  /* append current variable's name to output list */
  %let CurrentVar = %eval(&CurrentVar + 1);
%end;

%let DSID = %sysfunc(close(&DSID));
%do; &VarList %end;
%mend GetVarNames;
