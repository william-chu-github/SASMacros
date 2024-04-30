/*
Macro that assigns variables of a parent level proportionally to rows in the parent level.

PARENTTABLE: input dataset of parent items, where some variables, VARS, need to be allocated
  proportionally to child items... columns must include the PARENTIDS... must be unique and sorted
  by PARENTIDS
CHILDTABLE: input dataset of child items... for each PARENTIDS, their VARS will be divided
  proportionally among the rows of the child table... CHILDTABLE must include columns
  PARENTIDS, CHILDIDS, and PROPORTIONVAR... the rows of the child table should not overlap, or
  double-counting will happen in the allocation steps (e.g., if the parents are current
  CUs, and the children are PC_CBs, then the rows of the child table should be the sum of
  the BBs in both the PC_CB and CC_CU)
OUTDS: output dataset
PARENTIDS: space-separated list of variables that identifies the parent level
CHILDIDS: space-separated list of variables that identifies the child level, used solely
  for deterministic sorting of results... can pass in a null value to ignore
VARS: space-separated list of variables in the parent table to allocate proportionally
PROPORTIONVAR: the variable on the child input file to be used to calculate proportions...
  the variable is summed up over the PARENTIDS, and each input row has a certain percentage
  of this total... that percentage of each variable in VARS is assigned to the row
  the expectation is that each PARENTID will a nonzero sum of PROPORTIONVAR--otherwise proportions
  cannot be assigned, because there are no data--in this case, the macro will halt with an error
METHOD:
* 0 = no rounding (probably not suitable for integer-valued items like pop or dwelling counts)
* 1 = round top x: rounded to nearest integer (banker's rounding), then after sorting by
      descending variable value and ascending child IDs, modify the top few records by +/- 1
      per parent IDs to ensure the sum of the rounded values equals the input value at the
      parent ID value
      e.g., if three child records were allocated 9, 8, 5, but the total parent sum was 24,
      the allocation lost two items due to rounding... this option would add one item to the
      9 and 8 counts for a final allocation of 10, 9, 5, summing to the original 24
* 2 = adjust max value of parent group (after sorting by descending variable value and
      ascending child IDs) to ensure sum of output equals sum of input at the parent level
      e.g., repeating the above 9, 8, 5 example, this option only adjusts the top record, and
      the final allocation is 11, 8, 5

Macro creates temporary datasets which are later deleted, using %GetNewDSNames to prevent
collisions.
*/

%macro AssignProportional(
  ParentTable, ChildTable, OutDS, ParentIDs, ChildIDs, Vars, ProportionVar, Method
);
%if not (%sysfunc(index(012, &Method)))
  %then %do; %put ERROR: Method argument not 0, 1, 2; %abort cancel; %end;
%local Pos Currword MultiplyString ParentComma NumVars NewVars LastParent;
%let ParentComma = %Separate(&ParentIDs);
%let LastParent = %scan(&ParentIDs, -1);
%let NumVars = %sysfunc(countw(&Vars));
/* assuming here only variables need to be added to child table... can edit and combine
   parent + child if needed */
%let NewVars = %GetNewVarNames(&ChildTable, NumNames = &NumVars);
%let TempDS = %GetNewDSNames(NotAllowed = &OutDS);
%let Pos = 1;
%let CurrWord = %scan(&Vars, &Pos);
%let MultiplyString =;
%let OrigTotals =;
%do %until (&CurrWord = );
  %if (&CurrWord ~= )
    %then
      %do;
        %if (%length(&MultiplyString) > 0)
          %then %let MultiplyString = &MultiplyString, ;
        * each variable: divide proportion variable by parent-group total to get row fraction,
          then multiply by parent-group total ;
        %let MultiplyString = &MultiplyString Child.&ProportionVar / Z.&ProportionVar * Parent.&CurrWord as &CurrWord;
      %end;
  %let Pos = %eval(&Pos + 1);
  %let CurrWord = %scan(&Vars, &Pos);
%end;

proc sql;
create table &TempDS as
  select %Separate(&ParentIDs), sum(&ProportionVar) as GroupProportionSum
    from &ChildTable
    group by %Separate(&ParentIDs)
    having GroupProportionSum = 0;
quit;
run;
%ErrorOut(&TempDS, %str(Something went wrong: parent IDs have groups with zero &ProportionVar sum, impossible to calculate fractions));


* total of proportion variable at the parent level ;
proc sql;
create table &TempDS as
  select &ParentComma, sum(&ProportionVar) as &ProportionVar
    from &ChildTable
    group by &ParentComma
    order by &ParentComma;
quit;
run;
proc sql;
* calculate fraction of desired variables according to share of proportion variable ;
create table &OutDS as
  select %Separate(%Prefix(&ParentIDs, Child.)),
         %if (&ChildIDs ~= )
           %then %do; %Separate(%Prefix(&ChildIDs, Child.)), %end;
         &MultiplyString
    from &ChildTable Child, &TempDS Z, &ParentTable Parent
    where %Interleave(
            %Prefix(&ParentIDs, Child.), %Prefix(&ParentIDs, Parent.), Interleaver = %str( = ),
            Separator = %str( and )
          ) and
          %Interleave(
            %Prefix(&ParentIDs, Child.), %Prefix(&ParentIDs, Z.), Interleaver = %str( = ),
            Separator = %str( and )
          );
quit;
run;
proc sort data = &OutDS; by &ParentIDs &ChildIDs; run;

* now, need to round and adjust sums to original parent group ;
%if (&Method > 0)
  %then
    %do;
      * rounding... ;
      * could use arrays here, but would have to create a variable to loop, which could collide
        variable names... ;
      data &OutDS;
      set &OutDS;
      array OldVars(*) &Vars;
      array Counter(1) _temporary_;
      Counter(1) = 1;
      do while (Counter(1) <= dim(OldVars));
        OldVars(Counter(1)) = rounde(OldVars(Counter(1)));
        Counter(1) + 1;
      end;
      run;
      * calculate parent-level sum differences of the rounded data ;
      proc sql;
      create table &TempDS as
        select distinct %Separate(%Prefix(&ParentIDs, Parent.))
               /* for each allocation variable, calculate original parent level minus
                  rollup of rounded values... a positive value indicates items were lost
                  due to rounding, and the numbers in the output need to be adjusted up
                  (and the reverse for negative values) */
               %let Pos = 1;
               %let CurrWord = %scan(&Vars, &Pos);
               %do %until (&CurrWord = );
                 , Parent.&CurrWord - Sums.&CurrWord as %scan(&NewVars, &Pos)
                 %let Pos = %eval(&Pos + 1);
                 %let CurrWord = %scan(&Vars, &Pos);
               %end;
          from &ParentTable Parent,
               /* sum rounded values in a subtable */
               (select &ParentComma
                       %let Pos = 1;
                       %let CurrWord = %scan(&Vars, &Pos);
                       %do %until (&CurrWord = );
                         , sum(&CurrWord) as &CurrWord
                         %let Pos = %eval(&Pos + 1);
                         %let CurrWord = %scan(&Vars, &Pos);
                       %end;
                  from &OutDS
                  group by &ParentComma) Sums
          where %Interleave(
                  %Prefix(&ParentIDs, Parent.), %Prefix(&ParentIDs, Sums.), Interleaver = %str( = ),
                  Separator = %str( and )
                )
          order by &ParentComma;
      quit;
      run;
      data &OutDS;
      merge &OutDS &TempDS;
      by &ParentIDs;
      run;
      * now, loop through each variable and adjust rounding to sum to total ;
      %let Pos = 1;
      %let CurrWord = %scan(&Vars, &Pos);
      %do %until (&CurrWord = );
        proc sort data = &OutDS; by &ParentIDs descending &CurrWord &ChildIDs; run;
        %if (&Method = 1) /* adjust top x values by +/- 1*/
          %then
            %do;
              data &OutDS;
              set &OutDS;
              by &ParentIDs descending &CurrWord &ChildIDs;
              array Counter(1) _temporary_;
              retain Counter(1);
              if first.&LastParent
                then Counter(1) = 1;
                else Counter(1) + 1;
              if Counter(1) <= abs(%scan(&NewVars, &Pos))
                then
                  do;
                    /* differences were calculated as original minus rounded... positive value
                    indicates number needs to be adjusted up */
                    &CurrWord = &CurrWord + sign(%scan(&NewVars, &Pos));
                  end;
              run;
            %end;
        %if (&Method = 2) /* adjust top value */
          %then
            %do;
              data &OutDS;
              set &OutDS;
              by &ParentIDs descending &CurrWord &ChildIDs;
              if first.&LastParent
                then
                  do;
                    /* differences were calculated as original minus rounded... positive value
                    indicates number needs to be adjusted up */
                    &CurrWord = &CurrWord + %scan(&NewVars, &Pos);
                  end;
              run;
            %end;
        %let Pos = %eval(&Pos + 1);
        %let CurrWord = %scan(&Vars, &Pos);
       %end;
       data &OutDS;
       set &OutDS(drop = &NewVars);
       run;
    %end; 
data &OutDS; /* reorder columns */
retain &ParentIDs &ChildIDs &Vars;
set &OutDS;
run;
proc sort data = &OutDS; by &ParentIDs &ChildIDs; run;
/* QA assertion... input sum at parent level equals output sum */
proc summary data = &OutDS nway missing;
class &ParentIDs;
var &Vars;
output out = &TempDS(drop = _type_ _freq_) sum = ;
run;
proc compare data = &ParentTable c = &TempDS outnoequal outdif noprint out = &TempDS; id &ParentIDs; run;
%ErrorOut(&TempDS, Something went wrong: allocated counts do not sum to originals at parent level);
proc delete data = &TempDS; quit; run;
%mend;

