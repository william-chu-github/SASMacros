/*
Helper that creates an adjacency file based on line adjacencies (i.e., BB_AL),
given a "line" input file, and a polygon file linking the line "blocks" to the
geographic level of interest. This macro is therefore not appropriate for
pointwise adjacencies or overlapping adjacencies (PC_CB:CB clustering).
- LINE is the dataset detailing the basic left/right block relationship of
  the line objects. It must contain two variables: the value of BLOCK with
  "_R" appended, and with "_L" appended. e.g., BB_UID_L, BB_UID_R.
- POLY is the dataset linking the blocks of the line file to the higher
  geography whose adjacency relationships are required. The BLOCK variable
  must be in this dataset. Every other variable in the dataset is assumed to
  be a part of the unique identifier of the higher geography of interest.
- BLOCK is the unique ID variable for the block that is affiliated with
  the LINE and POLY files. Only one variable is allowed; the unique ID
  cannot be a combination of multiple variables for this macro.
- OUT is the output dataset to write the adjacency relationships. An existing
  file will be overwritten, and specifying the same file as LINE or POLY
  will probably result in an error. Based on the LINE and POLY inputs, the
  output file will list all higher geographic adjacencies. Self-adjacencies
  are excluded, as are adjacencies that are outside of the universe covered
  by the LINE file (e.g., polygon 0, or the national boundary). The adjacencies
  output will be two-sided; if X-adjacent-to-Y is in the file, then so is
  Y-adjacent-to-X. The output variables will be all of the non-BLOCK variables
  from POLY, and the same variables with "_ADJ" appended (e.g., DA_UID,
  DA_UID_ADJ). The sort order will be the non-ADJ variables, then the ADJ ones.
- STATIC is a space-separated list of variables in the LINES dataset to keep
  (e.g., a length variable for perimeter analysis, or an ID variable).
- SELF is 0/1; set to 1 if the link level is the actual one in the line layer
  and there is no need to merge.
- Keep0 is 0/1; set to 1 to keep arcs with non-"true" values on either the
  right or left side (e.g., national borders with CB_UID_R/L equal to zero).
- SelfExpand is a space-separated list of L/R attributes in the line table
  itself; these are to be expanded into adjacency relationships in the
  output. Do not include the _L/_R tags.
This macro creates and later deletes two datasets in WORK:
  Z_LineAdj_Linker Z_LineAdj_Vars

The output dataset creates a temporary variable which is later deleted:
  Z_LineAdj_Diff
In the unlikely event that a higher level geography has such a variable as a
part of its unique ID, the macro output will likely be wrong.
*/
%macro LineAdj(
  Line, Poly, Block, Out, Static = %str(),
  Self = 0, Keep0 = 0, SelfExpand = %str(),
);
%let Static = %trim(%left(&Static));
%local OtherBlocks LSide RSide RenameString Adj Pos Word OtherWord SelfOther;
* get variables in the linking file other than the block ;
proc contents data = &Poly noprint nodetails
  out = Z_LineAdj_Vars(keep = NAME VARNUM);
run;
proc sort data = Z_LineAdj_Vars(
  where = (upcase(left("&Block")) ~= upcase(NAME))
);
by VARNUM;
run;

%let Pos = 1;
%let Word = %scan(&SelfExpand, &Pos);
%do %while (&Word ~= );
  %let SelfOther = &SelfOther &Word._L &Word._R;
  %let Pos = %eval(&Pos + 1);
  %let Word = %scan(&SelfExpand, &Pos);
%end;

%let OtherBlocks = ;
proc sql noprint;
select NAME into :OtherBlocks separated by " " from Z_LineAdj_Vars;
quit;
run;
* if link level is actual one present in the line layer, no need to merge ;
%if (&OtherBlocks = )
  %then %do; %let OtherBlocks = &Block; %let Self = 1; %end;
  %else %if &Self
    %then %do; %let OtherBlocks = &Block &Otherblocks; %end;

%let LSide = %Suffix(&OtherBlocks, _L);
%let RSide = %Suffix(&OtherBlocks, _R);

%if (&OtherBlocks = or &Self)
  %then
    %do;
      proc sql;
      create table &Out as
        select &Block._L, &Block._R
               %if (&Static ~= %str())
                 %then , %Separate(&Static);
               %if (&SelfExpand ~= %str())
                 %then , %Separate(&SelfOther);
          from &Line
          %if (not &Keep0)
            %then where &Block._L and &Block._R;
          order by &Block._L, &Block._R;
      quit;
      run;
    %end;
  %else
    %do;
      proc sql;
      * sort linker ;
      create table Z_LineAdj_Linker as
        select * from &Poly order by &Block;
      * initialise adjacency file by joining on the left side of arcs ;
      create table &Out as
        select %if (&Static ~= %str())
                 %then %Separate(&Static), ;
               %if (&SelfExpand ~= %str())
                 %then %Separate(&SelfOther), ;
               &Line..&Block._R, Z_LineAdj_Linker.*
          from &Line left join Z_LineAdj_Linker
          on &Line..&Block._L = Z_LineAdj_Linker.&Block
          where %if (not &Keep0)
                  %then &Line..&Block._L and &Line..&Block._R and;
                &Line..&Block._L ~= &Line..&Block._R
          order by &Block._R;
      quit;
      run;

      * rename variables to append _L ;
      %let RenameString = %Interleave(&OtherBlocks, &LSide);
      proc datasets nolist nodetails;
      modify &Out;
      rename &RenameString;
      quit;
      run;

      * merge right side ;
      %let RenameString = %Interleave(&Block &OtherBlocks, &Block._R &RSide);
      data &Out(%if not &Self %then drop = &Block &Block._R;);
      merge &Out(in = Base) Z_LineAdj_Linker(rename = (&RenameString));
      by &Block._R;
      if Base;
      run;
      proc delete data = Z_LineAdj_Linker; run;
    %end;

proc sort data = &Out %if (&Static = %str()) %then nodupkey;;
by &LSide &RSide;
run;

%let Adj = %Suffix(&OtherBlocks, _ADJ);

* make adjacencies two-sided, and left/right neutral ;
data &Out(drop = &LSide &RSide Z_LineAdj_Diff &SelfOther);
set &Out;

%let Pos = 1;
%let Word = %scan(&SelfExpand, &Pos);
%do %while (&Word ~= );
  &Word = &Word._R;
  &Word._ADJ = &Word._L;
  %let Pos = %eval(&Pos + 1);
  %let Word = %scan(&SelfExpand, &Pos);
%end;
* output only if not self-adjacent ;
Z_LineAdj_Diff = 0;
%let Pos = 1;
%let Word = %scan(&OtherBlocks, &Pos);
%do %while (&Word ~= );
  %let OtherWord = %scan(&Adj, &Pos);
  * set base variable ;
  &Word = %scan(&RSide, &Pos);
  * set adjacent variable ;
  &OtherWord = %scan(&LSide, &Pos);
  * check if variables were different ;
  Z_LineAdj_Diff = Z_LineAdj_Diff + (&Word ~= &OtherWord);
  %let Pos = %eval(&Pos + 1);
  %let Word = %scan(&OtherBlocks, &Pos);
%end;
if Z_LineAdj_Diff then output;

%let Pos = 1;
%let Word = %scan(&SelfExpand, &Pos);
%do %while (&Word ~= );
  &Word = &Word._L;
  &Word._ADJ = &Word._R;
  %let Pos = %eval(&Pos + 1);
  %let Word = %scan(&SelfExpand, &Pos);
%end;
* make the relationship two-sided ;
Z_LineAdj_Diff = 0;
%let Pos = 1;
%let Word = %scan(&OtherBlocks, &Pos);
%do %while (&Word ~= );
  %let OtherWord = %scan(&Adj, &Pos);
  &Word = %scan(&LSide, &Pos);
  &OtherWord = %scan(&RSide, &Pos);
  Z_LineAdj_Diff = Z_LineAdj_Diff + (&Word ~= &OtherWord);
  %let Pos = %eval(&Pos + 1);
  %let Word = %scan(&OtherBlocks, &Pos);
%end;
if Z_LineAdj_Diff then output;
attrib _all_ label = "";
run;

proc sort data = &Out %if (&Static = %str()) %then nodupkey;;
by &OtherBlocks &Adj;
run;
proc delete data = Z_LineAdj_Vars; run;
%mend;
