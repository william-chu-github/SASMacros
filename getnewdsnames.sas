/*
* given a library, return dataset names which do not exist in the library--for
  ensuring no dataset overwriting ;
* NOTALLOWED is a space-separated list of names which are not allowed, useful for
  disallowing specified datasets that are not yet created
  e.g., user specifies dataset abc as output, but does not exist... passing in
  NOTALLOWED = ABC ensures ABC is not returned as a possible allowable name ;
* returned named list is space-separated and does not include a library reference ("libname.") ;
*/
%macro GetNewDSNames(Library = WORK, NumNames = 1, NotAllowed = %str());
%local NewDSNames CurrNum Created;
%let Created = 0;
%let CurrNum = 1;
%do %until (&Created >= &NumNames);
  %if not (%sysfunc(exist(&Library..NEWDS&CurrNum))) and
      not (%sysfunc(indexw(%upcase(&NotAllowed), NEWDS&CurrNum))) and
      not (%sysfunc(indexw(%upcase(&NotAllowed), %trim(%upcase(&Library)).NEWDS&CurrNum)))
    %then
      %do;
        %let Created = %eval(&Created + 1);
        %let NewDSNames = &NewDSNames NEWDS&CurrNum;
      %end;
    %let CurrNum = %eval(&CurrNum + 1);
%end;
%do; &NewDSNames %end;
%mend;
