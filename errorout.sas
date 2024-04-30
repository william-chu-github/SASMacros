* macro that stops SAS processing and prints an error message to the log if it is passed in
  a dataset that has more than zero rows (which it will print the first ten records) ;
%macro ErrorOut(DS, MSG);
%if %CountObs(&DS)
  %then
    %do;
       title "&MSG";
       proc print data = &DS(obs = 10); run;
       title;
       %put ERROR: &MSG;
       %abort cancel;
    %end;
%mend;

