/*
Macro that tries to proportionally allocate structures to entities, using proportions of
things already known to be in those entities. Results will not be exact since structure sizes
may not necessarily allow for near-exact allocations.

The use case is for putting all of a (large) building into the same block, when better
geocoding methods have failed. E.g., there are 10 units in structure 1, and their street
spans three different blocks. Say there are 5 units in structure 2, and their street spans
the same three blocks. If those three blocks have existing unit counts of 10, 2, 1, then
the macro assigns structure 1 to the block with 10 known units, and structure 2 to the block
with 2 known units. This is the closest possible to the input proportion.

STRUCTVAR: single variable uniquely identifying a structure
COUNTID: single numeric variable counting the units in the structure
PROPORTIONVAR: single numeric variable calculating the proportion of items in the PROPDS
SOURCEVARS: space-separated list of variables... these are the auxiliary variables used
  to assign to proportion... e.g., it would be the street ID in our example, since we
  want to assign the structure to a block based on how many records are already in the
  street-block intersection
TARGETVARS: space-separated list of variables... these are the locations to which we are
  trying to assign structures
STRUCTDS: dataset of structure info, with &StructID, &CountID, &SourceVars
PROPDS: dataset of proportion info, with &SourceVars, &TargetVars, &ProportionVar
SHOWCOUNTS: 0/1 indicator, whether to log progress by printing dataset counts... default 1

OUTDS: output dataset with &StructVar and &TargetVars, assigning each structure to
  the target variables... if a structure could not be assigned (no proportion data), then
  it is not output

e.g., in a file coding structures to block using street as the proportion allocator, consider:
PROPDS
block street frac
1     1      0.7
1     2      0.5
2     1      0.3
3     2      0.5

70% of already-allocated records on street 1 are in block 1, and 30% in block 2
50% of already-allocated records on street 2 are in block 1, and 50% in block 3

STRUCTDS
structid units street
1        50    1
2        20    2
3        5     1
4        15    3

call would be:
%AssignProp(STRUCTDS, PROPDS, structid, units, frac, street, block, assignmentresult);

The method used, briefly:
* given two input files, one with structure data and one with proportion data
  * sum the structure data over the source vars, and multiply by the proportion data to figure
    out the assignment count that would exactly match the proportion
  * in our example, structures 1 and 3 are on street 1, for a total of 55 units to assign
  * according to the proportion data, 70% of street 1 records are in block 1, so try to
    target adding 0.7 * 55 = 38.5 dwellings of the structures to be assigned
  * since dwellings in the structure must be assigned together, we cannot ever exactly match
    this target
  * the macro tries to fit things as best as possible by processing largest structures
    against the largest target counts first
  * in the example, the 50 units in structure 1 are assigned to block 1... this more than
    covers the target of 38.5 dwellings, so block 1 is removed from consideration for the rest
    of the street 1 assignments
  * the five dwellings of structure 3 are assigned to block 3, which is not sufficient to
    cover the target of 11.5, but there are no further dwellings on street 1 to assign


*/
%macro AssignProp(
  StructDS, PropDS, StructVar, CountID, ProportionVar, SourceVars, TargetVars,
  OutDS, ShowCounts = 1
);
%local Left Target LastSource TempAdds TargetCount Units DelUnits VarNameList OldNotesOption;
%let TempAdds = %GetNewDSNames();
data &TempAdds; run;
%let TargetData = %GetNewDSNames();
data &TargetData; run;
%let TopTargets = %GetNewDSNames();
data &TopTargets; run;
%let Structs = %GetNewDSNames();
data &Structs; run;
%let TopStructs = %GetNewDSNames();
data &TopStructs; run;

* need some temporary variable names that will not clash with the input data ;
data &TempAdds;
set &StructDS(obs = 0) &PropDS(obs = 0);
run;
%let VarNameList = %GetNewVarNames(&TempAdds, NumNames = 3);
%let TargetCount = %scan(&VarNameList, 1);
%let Units = %scan(&VarNameList, 2);
%let DelUnits = %scan(&VarNameList, 3);

%let LastSource = %scan(&SourceVars, -1);
proc sql;
create table &TargetData(drop = Frac) as
  select Prop.*, ceil(Prop.Frac * Struct.&CountID) as &TargetCount
    from (select %Separate(&SourceVars), sum(&CountID) as &CountID
            from &StructDS group by %Separate(&SourceVars)) Struct,
         &PropDS Prop
    where %Interleave(
            %Prefix(&SourceVars, %str(Struct.)),
            %Prefix(&SourceVars, %str(Prop.)),
            Separator = %str( and )
          )
    order by %Separate(&SourceVars), &TargetCount desc, &ProportionVar desc,
             %Separate(&TargetVars);
    /* above, include original count in sorting, because the ceil() could create false ties */
quit;
run;
proc sort data = &StructDS out = &Structs;
by &SourceVars descending &CountID &StructVar;
run;
* initialise empty dataset to populate structure: targetvars relationship ;
proc sql;
create table &OutDS like &PropDS(keep = &TargetVars);
alter table &OutDS add &StructVar num;
quit;
run;
%let OldNotesOption = %sysfunc(getoption(notes));
options nonotes;

%do %while(%CountObs(&Structs));
  %if (&ShowCounts)
    %then %put Proportion macro, structures left to assign: %CountObs(&Structs);
  * split out top struct per street ;
  data &Structs &TopStructs;
  set &Structs;
  by &SourceVars;
  if first.&LastSource then output &TopStructs; else output &Structs;
  run;
  * target record needing the most total target count per SOURCEVARS group ;
  data &TopTargets;
  set &TargetData;
  by &SourceVars;
  if first.&LastSource;
  run;
  * assign structures to the targets ;
  proc sql;
  create table &TempAdds as
    select &StructVar,
           %Separate(%Prefix(&SourceVars, %str(B.))),
           %Separate(%Prefix(&TargetVars, %str(B.))), &CountID
      from &TopStructs A, &TopTargets B
      where %Interleave(
              %Prefix(&SourceVars, %str(A.)), %Prefix(&SourceVars, %str(B.)),
              Separator = %str( and )
            )
      order by %Separate(&SourceVars), %Separate(&TargetVars);
  quit;
  run;
  * update target count dataset ;
  proc sort data = &TargetData;
  by &SourceVars &TargetVars;
  run;
  data &TargetData(drop = &DelUnits);
  merge
    &TargetData
    &TempAdds(keep = &SourceVars &TargetVars &CountID rename = (&CountID = &DelUnits) in = Del)
  ;
  by &SourceVars &TargetVars;
  if Del then &TargetCount = &TargetCount - &DelUnits;
  if &TargetCount <= 0 then delete;
  run;
  proc sort data = &TargetData; /* revert to neediest record on top */
  by &SourceVars descending &TargetCount &TargetVars;
  run;
  proc append base = &OutDS data = &TempAdds(keep = &TargetVars &StructVar); run;
%end;
options &OldNotesOption;
proc delete data = &TempAdds &TopTargets &TargetData &Structs &TopStructs; run;
%mend;

/*
data structs;
structid = 1; units = 50; street = 1; output;
structid = 2; units = 20; street = 2; output;
structid = 3; units =  5; street = 1; output;
structid = 4; units = 15; street = 3; output;
run;
data props;
block = 1; street = 1; frac = 0.7; output;
block = 1; street = 2; frac = 0.5; output;
block = 2; street = 1; frac = 0.3; output;
block = 3; street = 2; frac = 0.5; output;
run;

%AssignProp(structs, props, structid, units, frac, street, block, assignmentresult);
*/
