/*
* utility macro that gives new variable names that are not in the input dataset ;
* useful for ensuring no name collisions in macro code ;
* DS: input dataset--don't create variable names that already exist in it ;
* NUMNAMES: number of variables to create (will be of pattern NEWNAME<number>) ;
* EXCLUSIONS: space-separated list of names not to use, which are not already in the dataset...
  useful in case variables with specific names must be added to the dataset later ;
*/
%macro GetNewVarNames(DS, NumNames = 1, Exclusions = %str()) /minoperator;
%local NewVarNames CurrNum Created DSID CurrVarOK;
%let Created = 0;
%let DSID = %sysfunc(open(&DS));
%let CurrNum = 1;
%let Exclusions = %upcase(&Exclusions);
%do %until (&Created >= &NumNames);
  %let CurrVarOK = 0;
  /*
  * generated variable name is OK if it is not currently on the dataset
  * and it is not in the exclusion list
  * SAS does not like empty argument for in operator, which is causing a need for complicated logic here...
  */
  %let CurrVarOK = not (%sysfunc(varnum(&DSID, NEWNAME&CurrNum)));
  %if (&CurrVarOK)
    %then
      %do;
        %if (&Exclusions ~= )
          %then
            %do;
              %let CurrVarOK = not (NEWNAME&CurrNum in (&Exclusions));
            %end;
      %end;
  %if (&CurrVarOK)
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
