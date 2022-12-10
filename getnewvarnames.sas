/*
* utility macro that gives new variable names that are not in the input dataset ;
* useful for ensuring no name collisions in macro code ;
* DS: input dataset--don't create variable names that already exist in it ;
* NUMNAMES: number of variables to create (will be of pattern NEWNAME<number>) ;
*/
%macro GetNewVarNames(DS, NumNames = 1);
%local NewVarNames CurrNum Created DSID;
%let Created = 0;
%let DSID = %sysfunc(open(&DS));
%let CurrNum = 1;
%do %until (&Created >= &NumNames);
  %if not (%sysfunc(varnum(&DSID, NEWNAME&CurrNum)))
    %then
      %do;
        %let Created = %eval(&Created + 1);
        %let NewVarNames = &NewVarNames NEWNAME&CurrNum;
      %end;
    %let CurrNum = %eval(&CurrNum + 1);
%end;
%let DSID = %sysfunc(close(&DSID));
%do; &NewVarNames %end;
%mend;
