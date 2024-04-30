/*
A macro to simplify downloads from ORACLE databases, where no complex
joins, calculations, or groupings are required. It can select which variables
to download, which variables to sort, and the source/destination tables.

Its sole argument, ARGS, is a formatted string detailing these simple
requirements. Its expected format is:
  destination_name_1!source_name_1|download_variables_1|sort_variables_1#
  ...
  destination_name_n!source_name_n|download_variables_n|sort_variables_n#

The hashes (#) separate the argument into a list of tables and specifications
for downloading them. The bars (|) separate the parameters of each table
specification.

The first parameter of the table specification is the source table from which
to copy, and the destination table to which to write. If there is an exclamation
mark (!) in the first component of the table specification, then the text
before it defines the table to which to write, and the part after defines the
source table. Otherwise, the whole first component is used as the source, and
the destination will be the member name of the component, written to WORK. Thus
errors are possible if the source table is from WORK.

Each table specification must have two or three components (and thus one or two
bars separating them).

If the specification has two components, then the second component is assumed
to be a space-separated list of variables to be used as the list of variables
to download from the source table, as well as the ascending sort order.

If the specification has three components, the second is assumed to be a
space-separated list of variables to download, and the third is assumed to
be a space-separated list of the ascending order sort variables.
*/

* A sample call ;
/*
%SimpleDL(
  CB!WH.WC2006CB_20060630|CB_UID PRCODE CDCODE CT_PCT_CODE DACODE|CB_UID#
  DA!WH.WC2006DA_20060630|DA_UID PRCODE CDCODE DACODE CSDCODE#
  WH.WC2006CSD_20060630|CSD_UID#
  WH.WC2006PR_20060630|PRCODE|PRCODE|this is a fourth component#
);

The first specification creates table WORK.CB from WH.WC2006CB_20060630. It
downloads CB_UID through DACODE, sorting by CB_UID.

The second specification create WORK.DA from WH.WC2006DA_20060630, extracting
DA_UID through CSDCODE, and sorting by those same variables.

The third specification creates WORK.WC2006CSD_20060630 from the WH library of
the same member name, copying and ordering by CSD_UID.

The fourth specification results in an error, because there are too many
components to the table specification.
*/
%macro SimpleDL(Args);
%local Pos Word NumParams Tab Copy Source SelectString SourceString;
proc sql;
%* loop through each table specification, separated by # signs ;
%let Pos = 1;
%let Word = %scan(&Args, &Pos, %str(#));
%do %while (%quote(&Word) ~= );
  %* check the number of parameters ;
  %let NumParams = %sysfunc(countc(&Word, %str(|))) + 1;
  %if (&NumParams ~= 2 and &NumParams ~= 3)
    %then
      %do;
        %put Hey moron, read the macro documentation before using it.;
        %put Your argument was: &Word;
        %abort;
      %end;
  %* get table source/destination ;
  %let Tab = %scan(&Word, 1, %str(|));
  %if (%index(&Tab, %str(!)))
    %then
      %* destination specified ;
      %do;
        %let Copy = %scan(&Tab, 1, %str(!));
        %let Source = %scan(&Tab, 2, %str(!));
      %end;
    %else
      %* destination not specified, so use the same member name as source,
        but copy to WORK ;
      %do;
        %let Source = &Tab;
        %if (%index(&Source, %str(.)))
          %then %let Copy = %scan(&Source, 2, %str(.));
          %else %let Copy = &Source;
      %end;
  %if (&NumParams = 3)
    %then
      %* separate lists of variables to extract and sorting variables ;
      %do;
        %let SelectString = %separate(%scan(&Word, 2, %str(|)));
        %let SortString = %separate(%scan(&Word, 3, %str(|)));
      %end;
    %else
      %* only one variable list, so use it to both extract and sort ;
      %do;
        %let SelectString = %separate(%scan(&Word, 2, %str(|)));
        %let SortString = &SelectString;
      %end;

  %* download the data ;
  create table &Copy as
    select &SelectString
      from &Source
      order by &SortString;
  %let Pos = %eval(&Pos + 1);
  %let Word = %scan(&Args, &Pos, %str(#));
%end;
quit;
run;
%mend;
