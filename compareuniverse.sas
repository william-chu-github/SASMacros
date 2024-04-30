/*
Given two datasets of universes of unique IDs, either print a list of the
first 10 mismatched IDs, or create a dataset of all mismatched IDs.
- DS1, DS2 are the two datasets to compare.
- ID is a space-separted list of unique ID keys.
- OUTDS, when blank, prints the first ten mismatched; when non-blank, outputs
  all mismatched to the specified dataset.
- Output variables are the keys suffixed with "_1" or "_2", depending on
  whether they were extracted from the first or second dataset.
*/
%macro CompareUniverse(DS1, DS2, ID, OutDS =);
%local First;
%let First = %scan(&ID, 1);
%if (&OutDS =)
  %then
    %do;
      proc sql outobs = 10;
    %end;
  %else
    %do;
      proc sql;
      create table &OutDS as
    %end;
       select distinct %Interleave(
         %Prefix(&ID, A.), %Suffix(&ID, _1),
        Interleaver = %str( as ), Separator = %str(, )
       ), 
       %Interleave(
         %Prefix(&ID, B.), %Suffix(&ID, _2),
         Interleaver = %str( as ), Separator = %str(, )
       )
  from (select distinct %Separate(&ID) from &DS1) A full join (select distinct %Separate(&ID) from &DS2) B
  on %Interleave(%Prefix(&ID, A.), %Prefix(&ID, B.), Separator = %str( and ))
  where A.&First is missing or B.&First is missing;
quit;
run;
%mend;
