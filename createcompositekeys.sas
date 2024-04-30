* rewrite to just do a numeric sequential key over unique variable combinations, and return a specified mapping dataset linking the key and the blocks ;
* overwriting input adj/block files ;

* helper macro to create a sequential integer composite key for unique combinations of block variables in a block file--for use in conjunction with %cluster ;
* useful to reduce multiple keys into one since it helps merging performance ;
* - ADJ is the input adjacency file, which will be overwritten (can prevent overwriting permanent files by copying and calling with the copy)
* - BLOCK is the input block file
* - VARS is the space-separated list of variable names which identify the "block" of a cluster
* - KEYNAME is the variable name to use for the composite key ;
* BLOCK dataset is unduplicated by the block variables, and then a sequential integer KEYNAME variable is added, identifying unique combinations of blocks ;
* ADJ dataset is edited to include KEYNAME and KEYNAME_ADJ according to the calculation in the BLOCK dataset, and unduplicated on all variables ;
* %cluster can then be called with the ADJ and BLOCK, and the results can be related back to the true blocks using variables on the BLOCK file ;
%macro CreateCompositeKeys(Adj, Block, Vars, KeyName = CompositeKey);
* generate the SQL join string for joining the blocks on both sides, and
  generate renaming string at the same time ;
%let MatchStringL =
  %Interleave(
    %Prefix(&Vars, L.), %Prefix(&Vars, Adj.), Separator = %str( and )
  );
%let MatchStringR =
  %Interleave(
    %Prefix(%Suffix(&Vars, _ADJ), Adj.), %Prefix(&Vars, R.), Separator = %str ( and )
  );

proc sort data = &Block nodupkey;
by &Vars;
run;
data &Block;
set &Block;
&KeyName = _n_;
run;
%local TempTab;
%let TempTab = %GetNewDSNames(NumNames = 1);
proc sql;
create table &TempTab as
  select distinct L.&KeyName, R.&KeyName as &KeyName._ADJ, Adj.*
    from &Adj Adj left join &Block L
    on &MatchStringL left join &Block R
    on &MatchStringR;
quit;
run;
data &Adj;
set &TempTab;
run;
proc delete data = &TempTab; run;
%mend;
