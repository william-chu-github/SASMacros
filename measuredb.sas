/*
Macro to lift unique ID and internal area value from a spatial table.

Usage:
%MeasureDB(
  TABLE_NAME, OUT_TABLE, UNIQUE_ID, TYPE = AREA|LENGTH,
  DB = DATABASE, SCHEMA = OWNER, USER = USERNAME
);

- TABLE_NAME is the table name under the SCHEMA (defaults to WAREHOUSE)
  on the DATABASE (defaults to GEODEPOT.GEO.STATCAN.CA)
- OUT_TABLE is the table in WORK to which to write the UNIQUE_ID and AREA
  variables
- USERNAME is a user who has access to the schema (defaults to CHUWILL)--
  a password prompt will appear
- TYPE (AREA or LENGTH) determines whether the macro downloads area or length--
  defaults to AREA
*/
%macro MeasureDB(
  InTab, OutTab, ID, Type = A,
  DB = GEODEPOT.GEO.STATCAN.CA,
  Schema = WAREHOUSE,
  User = CHUWILL
);
%local LayerID;
%let InTab = %upcase(&InTab);
%let Schema = %upcase(&Schema);
%let Type = %upcase(%left(%trim(&Type)));
%if &Type = AREA %then %let Type = A;
%if &Type = LENGTH %then %let Type = L;
%if &Type ~= L and &Type ~= A
  %then
    %do;
      %put Error: incorrect TYPE argument;
      %goto Exit;
    %end;

proc sql noprint;
connect to oracle as DB(
  user = &User path = &DB dbprompt = yes
);
select LAYER_ID into :LayerID from connection to DB (
  select OWNER, TABLE_NAME, LAYER_ID from SDE.LAYERS
) where OWNER = "&Schema" and TABLE_NAME = "&InTab";
%let LayerID = %trim(&LayerID);
/* determine if F-table exists (use it to get area/length) or it is integrated (use ST_GEOM) */
select count(*) into :TableExists from connection to DB (
  select * from ALL_TABLES where OWNER = %str(%')&Schema%str(%') and TABLE_NAME = %str(%')F&LayerID%str(%')
);
%if &TableExists
  %then
    %do;
      create table &OutTab as select * from connection to DB (
        select %Separate(&ID), %if &Type = A %then B.AREA; %else B.LEN;
          from &Schema..&InTab A, &Schema..F&LayerID B
          where A.SHAPE = B.FID
          order by %Separate(&ID)
      );
    %end;
  %else
    %do;
      create table &OutTab as select * from connection to DB (
        select %Separate(&ID), %if &Type = A %then SDE.ST_AREA(SHAPE) as AREA; %else SDE.ST_LENGTH(SHAPE) as LEN;
          from &Schema..&InTab
          order by %Separate(&ID)
      );
    %end;
disconnect from DB;
quit;
run;
%Exit:
%mend;


