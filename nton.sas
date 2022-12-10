/*
Macro that takes the polygon overlap relationships of two geographic
hierarchies in an input file and outputs whether they are 1:1, 1:n, n:1, or n:n.
- BLOCKS is the input SAS dataset. It must have the variables listed in ID1 and
  ID2. It completely lists the distinct block-to-block relationships.
- ID1 is the space-separated list of variables from BLOCKS that uniquely
  identifies the first geography.
- ID2 is the list of variables that uniquely identifies the second geography.
- OUT is the file to which to write the output. Variables included will be those
  listed in ID1 and ID2, plus RELATIONSHIPNN, which is the relationship type
  of the ID1 block to the ID2 block for the record. It also includes ID2Count
  (the number of ID2 "blocks" the ID1 "block" key overlaps) and ID1Count
  (the number of ID1 "blocks" the ID2 "block" key overlaps).
  
  OUT is a relationship-level output file, so IDs which are split will occur
  multiple times. Although BLOCK can probably be the same as OUT, overwriting
  is not recommended.

This macro creates and deletes several datasets in WORK:
  Z_NtoN_Side1 Z_NtoN_Side2 Z_NtoN_11 Z_NtoN_1n Z_NtoN_n1
*/
%macro NtoN(Blocks, ID1, ID2, Out);
%local ID1Comma ID2Comma;
* remove duplicate records if they exist ;
proc sort data = &Blocks(keep = &ID1 &ID2) out = &Out nodupkey;
by &ID1 &ID2;
run;
* comma-separate lists for use in SQL ;
%let ID1Comma = %separate(&ID1);
%let ID2Comma = %separate(&ID2);
proc sql;
* count the number of ID2 blocks overlapping each ID1 block ;
create table Z_NtoN_Side1 as
  select &ID1Comma, count(*) as ID2Count
    from &Out
    group by &ID1Comma
    order by &ID1Comma;
* count the number of ID1 blocks overlapping each ID2 block ;
create table Z_NtoN_Side2 as
  select &ID2Comma, count(*) as ID1Count
    from &Out
    group by &ID2Comma
    order by &ID2Comma;
quit;
run;
* merge the counts into the unduplicated block relationship file ;
data &Out;
merge &Out Z_NtoN_Side1;
by &ID1;
run;
proc sort data = &Out; by &ID2; run;
data &Out;
merge &Out Z_NtoN_Side2;
by &ID2;
run;
proc sort data = &Out; by &ID1 &ID2; run;

proc sql;
* a relationship is 1:1 if both the ID1 and ID2 blocks link only to one
  of the opposite block ;
create table Z_NtoN_11 as
  select distinct &ID1Comma, &ID2Comma
    from &Out
    where ID1Count = 1 and ID2Count = 1
    order by &ID1Comma, &ID2Comma;
* an ID1 block is 1:n if all overlapping ID2 blocks link to a maximum of one
  ID1 block, and the ID1 block links to multiple ID2 blocks ;
create table Z_NtoN_1n as
  select distinct &ID1Comma, &ID2Comma
    from &Out
    where ID2Count > 1
    group by &ID1Comma
    having max(ID1Count) = 1
    order by &ID1Comma, &ID2Comma;
* reverse of the 1:n case ;
create table Z_NtoN_n1 as
  select distinct &ID1Comma, &ID2Comma
    from &Out
    where ID1Count > 1
    group by &ID2Comma
    having max(ID2Count) = 1
    order by &ID1Comma, &ID2Comma;
quit;
run;
* merge in relationships ;
data &Out;
merge &Out Z_NtoN_11(in = In11) Z_NtoN_1n(in = In1n) Z_NtoN_n1(in = Inn1);
by &ID1 &ID2;
select;
  when (In11) RelationshipNN = "1:1";
  when (In1n) RelationshipNN = "1:n";
  when (Inn1) RelationshipNN = "n:1";
  otherwise   RelationshipNN = "n:n";
end;
run;
proc delete data = Z_NtoN_Side1 Z_NtoN_Side2 Z_NtoN_11 Z_NtoN_1n Z_NtoN_n1;
run;
%mend;
