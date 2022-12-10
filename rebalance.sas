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

This macro creates one auxiliary dataset which is deleted after execution:
Z_Rebalance_Levels

It also creates temporary variables in the output dataset which could
possibly interfere with existing variables. The variable names are exactly
the ones listed in REBALVARS, but with "_SUM" suffixed.

Example:
%Rebalance(Alloc, Alloc, POP DWELL, ALLOC_POP ALLOC_DWELL, DA_UID);
The parent geographic level is DA_UID. The objective is to adjust the
first occurrence of each DA_UID so that the sum of ALLOC_POP and ALLOC_DWELL
in every DA is equal to the listed values of POP and DWELL. No guarantee is
given that the allocation will yield only non-negative values, so it would
be beneficial to have the input dataset sorted by DA_UID and descending size.
*/
%macro Rebalance(InDS, OutDS, SourceVars, RebalVars, LevelVars);
%local SumVars LastLevel;
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
* calculate sum of allocation over levels ;
proc summary data = &OutDS nway missing;
class &LevelVars;
var &RebalVars;
output out = Z_Rebalance_Levels(drop = _type_ _freq_) sum = /autoname;
run;
* merge sums with data ;
data &OutDS;
merge &OutDS Z_Rebalance_Levels;
by &LevelVars;
run;
* adjust first occurrence of level so allocated sum is equal to real value ;
data &OutDS(drop = I &SumVars);
set &OutDS;
by &LevelVars;
array SourceVars (*) &SourceVars;
array RebalVars (*) &RebalVars;
array SumVars (*) &SumVars;
do I = 1 to dim(SourceVars);
  if first.&LastLevel
    then RebalVars(I) = RebalVars(I) - (SumVars(I) - SourceVars(I));
end;
run;
proc delete data = Z_Rebalance_Levels; run;
%mend;
