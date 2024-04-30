/*
Macro that adjusts numeric allocations so they sum up to originals at a
given level. No guarantee is given that the final results will be
non-negative, so it is safest to round down in an allocation where
fractions are possible. The first "block" of a level will be adjusted
to have the total sum of the blocks' allocations equal to the original
input level. Thus it is beneficial to have the block with the largest
allocation listed first, to yield the least percentage change. Thus the
this macro may not be suitable if there are multiple variables being
rounded, and the "biggest" block is different for each variable.
- INDS is the input dataset. It must be sorted by LEVELVARS. It must
  have the numeric variables listed in SOURCEVARS and REBALVARS. The values
  in REBALVARS are record-level values (e.g., dwellings assigned to the
  portion of the DA in that record), whereas the values in SOURCEVARS
  are geo-level values (e.g., the number of dwellings in the DA) and
  are therefore constant over the parent geography.
- OUTDS is the output dataset, which will be the same as the input one,
  but with allocation variables nudged to sum to expected totals. If INDS
  is the same as OUTDS, it will be overwritten.
- SOURCEVARS is a space-separated list of the original values
  of the variables at the parent level.
- REBALVARS is a space-separted list of the allocated, rounded
  values. These are the variables that must add up to the SOURCEVARS at
  the parent level.
- LEVELVARS is a space-separated list of the parent geographic level whose
  summed allocation values are to be maintained.

Example:
%Rebalance(Alloc, Alloc, POP DWELL, ALLOC_POP ALLOC_DWELL, DA_UID);
The parent geographic level is DA_UID. The objective is to adjust the
first occurrence of each DA_UID so that the sum of ALLOC_POP and ALLOC_DWELL
in every DA is equal to the listed values of POP and DWELL. No guarantee is
given that the allocation will yield only non-negative values, so it would
be beneficial to have the input dataset sorted by DA_UID and descending size.
*/
%macro Rebalance(InDS, OutDS, SourceVars, RebalVars, LevelVars);
%local SumVars LastLevel TempDS TempVar;
%let SourceVars = %left(%cmpres(%trim(&SourceVars)));
%let RebalVars = %left(%cmpres(%trim(&RebalVars)));
* create list of sum variables over each level where rebalancing occurs ;
%let SumVars = %Suffix(&RebalVars, _sum);
* for identifying FIRST./LAST. in a sorted datastep ;
%let LastLevel = %scan(&LevelVars, -1);

* create output dataset ;
%let InDS = %upcase(%trim(&InDS));
%let OutDS = %upcase(%trim(&OutDS));
%if (&InDS ~= &OutDS)
  %then
    %do;
      data &OutDS;
      set &InDS;
      run;
    %end;

%local TabNames InitialSum ParentCount;
%let TabNames = %GetNewDSNames(NumNames = 2);
%let InitialSum = %scan(&TabNames, 1);
%let ParentCount = %scan(&TabNames, 2);

* calculate sum of allocation over levels ;
proc summary data = &OutDS nway missing;
class &LevelVars;
var &RebalVars;
output out = &InitialSum(drop = _type_ _freq_) sum = &SourceVars;
run;
proc sql;
create table &ParentCount as
  select distinct %Separate(&LevelVars), %Separate(&SourceVars)
    from &InDS
    order by %Separate(&LevelVars);
quit;
run;
proc compare
  data = &InitialSum c = &ParentCount
  out = &ParentCount(
    drop = _type_ _obs_
    rename = (
      %Interleave(&SourceVars, &RebalVars)
    )
  )
  noprint
;
/*
numeric result of the proc compare is <compare> minus <base>
if <global value> is bigger than <allocated sum>, there is a deficit in the allocation,
and the difference needs to be added to the raw count
if <global value> is smaller than <allocated sum>, there is a surplus in the allocation,
and the difference needs to be subtracted from the raw count
so, <parent count> minus <initial sum> is negative->surplus in allocation->
adding a negative to the raw count makes it smaller and rebalances
<parent count> minus <initial sum> is positive->deficit in allocation->
adding a positive to the raw count makes it larger and rebalances
*/
id &LevelVars;
run;

* split dataset into first occurrence per geo level (this is the record that will be adjusted
  to rebalance) and rest of the dataset ;
data &InitialSum(keep = &LevelVars &RebalVars) &OutDS;
set &OutDS;
by &LevelVars;
output &OutDS;
if first.&LastLevel
  then output &InitialSum;
run;


* sum the raw value and the adjustment ;
data &InitialSum;
set &InitialSum &ParentCount;
run;


proc summary data = &InitialSum nway;
class &LevelVars;
var &RebalVars;
output out = &InitialSum(drop = _type_ _freq_) sum = ;
run;

%let TempVar = %GetNewVarNames(&OutDS);
%let TempDS = %GetNewDSNames();
data &OutDS &TempDS;
set &OutDS;
&TempVar = _n_;
by &LevelVars;
if first.&LastLevel
  then output &TempDS;
  else output &OutDS;
run;
data &TempDS;
update &TempDS &InitialSum;
by &LevelVars;
run;
data &OutDS(drop = &TempVar);
set &TempDS &OutDS;
by &TempVar;
run;
proc delete data = &InitialSum &ParentCount &TempDS; run;
%mend;
