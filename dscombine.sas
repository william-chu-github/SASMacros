/*
A macro that takes multiple datasets with the same layout, and combines them
into one big dataset.
- LIST is a SAS dataset with a the string variable LISTVAR. It lists the
  datasets to combine. The datasets listed must actually exist, and have
  the same layout, or appending will fail.
- LISTVAR is the is the full name (library, dot, and dataset name) of each
  dataset to be combined. Datasets in WORK probably don't need to have the
  libref included.
- OUT is the output dataset once all the inputs have been combined. Overwriting
  one of the input datasets is allowed, but not recommended, since appending
  is used, which does not necessarily preserve the original relationships if
  an error occurs.
This macro creates temporary datasets in WORK:
  Z_DSCombine_Left Z_DSCombine_Append Z_DSCombine_Curr
which are deleted after execution finishes.
*/
%macro DSCombine(List, ListVar, Out);
%local FirstTab DSList;
* the list will be modified, so make a copy ;
data Z_DSCombine_Left(keep = &ListVar where = (&ListVar ~= ""));
set &List;
run;
proc sort data = Z_DSCombine_Left nodupkey; by &ListVar; run;
* if there are things to append, then initialise the output dataset with
  the expected data columns ;
%if (%CountObs(DS = Z_DSCombine_Left) > 0)
  %then
    %do;
      proc sql noprint;
      select &ListVar into :FirstTab from &List;
      create table &Out like &FirstTab;
      quit;
      run;
    %end;

%do %while (%CountObs(DS = Z_DSCombine_Left) > 0);
  * max macro length 65534/42 (8*lib, 1*dot, 32*member, 1*separator)
    = 1500 records at a time ;
  data Z_DSCombine_Left Z_DSCombine_Curr;
  set Z_DSCombine_Left;
  if _n_ <= 1500
    then output Z_DSCombine_Curr;
    else output Z_DSCombine_Left;
  run;
  * get a list of the current batch of dataset names ;
  proc sql noprint;
  select &ListVar into :DSList separated by " " from Z_DSCombine_Curr;
  quit;
  run;
  * generate a dataset to append to the output ;
  data Z_DSCombine_Append;
  set &DSList;
  run;
  * append ;
  proc append base = &Out data = Z_DSCombine_Append force; run;
%end;
proc delete data = Z_DSCombine_Left Z_DSCombine_Append Z_DSCombine_Curr; run;
%mend;
