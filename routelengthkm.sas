/*
Macro that calculates BB-level routelength (km) given specified tabular/DB
parameters:
- LINETAB is the BB_AL table
- LINKTAB is the BB_AL_TO_A_LINK table
- BBTAB is the BB_A table
- OUTTAB is the output file to which to write; it will have columns BB_UID
  (forming a complete set of BBs found on the BB input table) and
  LENGTH (length of non-BOs in km)
- DB is the database from which to download the tables (same for all tables)
- SCHEMA is the database schema from which to download
- USER is the username to use to connect to the DB

e.g.,
  %RouteLengthKM(
    WC2011BB_AL_20070920, WC2011BB_AL_TO_A_LINK_20070920,
    WC2011BB_A_20070920, RouteLength
  );
*/
%macro RouteLengthKM(
  LineTab, LinkTab, BBTab, OutTab,
  DB = GEODEPOT.GEO.STATCAN.CA,
  Schema = WAREHOUSE,
  User = CHUWILL
);
%local LayerID;
%let Schema = %upcase(%left(%trim(&Schema)));
%let LineTab = %upcase(%left(%trim(&LineTab)));
%let LinkTab = %upcase(%left(%trim(&LinkTab)));
%let BBTab = %upcase(%left(%trim(&BBTab)));

%local TabNames ZBBTab ZLineTab ZLinkTab ZExpandTab;
%let TabNames = %GetNewDSNames(NumNames = 4);
%let ZBBTab = %scan(&TabNames, 1);
%let ZLineTab = %scan(&TabNames, 2);
%let ZLinkTab = %scan(&TabNames, 3);
%let ZExpandTab = %scan(&TabNames, 4);

proc sql noprint;
connect to oracle as DB(
  user = &User path = &DB dbprompt = yes
);
select LAYER_ID into :LayerID from connection to DB (
  select OWNER, TABLE_NAME, LAYER_ID from SDE.LAYERS
) where OWNER = "&Schema" and TABLE_NAME = "&LineTab";
%let LayerID = %trim(&LayerID);
/* determine if F-table exists (use it to get area/length) or it is integrated (use ST_GEOM) */
select count(*) into :TableExists from connection to DB (
  select * from ALL_TABLES where OWNER = %str(%')&Schema%str(%') and TABLE_NAME = %str(%')F&LayerID%str(%')
);
%if &TableExists
  %then
    %do;
      %put F-table;
      create table &ZLineTab as select * from connection to DB (
        select NGD_UID, SGMNT_TYP_CDE, B.LEN / 1000 as LENGTH
          from &Schema..&LineTab A left join &Schema..F&LayerID B
          on A.SHAPE = B.FID
          order by NGD_UID
      );
    %end;
  %else
    %do;
      %put ST-GEOM;
      create table &ZLineTab as select * from connection to DB (
        select NGD_UID, SGMNT_TYP_CDE, SDE.ST_LENGTH(SHAPE) / 1000 as LENGTH
          from &Schema..&LineTab
          order by NGD_UID
      );
    %end;
create table &ZLinkTab as select * from connection to DB (
  select NGD_UID, BB_UID_L, BB_UID_R
    from &Schema..&LinkTab
    order by NGD_UID
);
create table &ZBBTab as select * from connection to DB (
  select BB_UID
    from &Schema..&BBTab
    order by BB_UID
);
quit;
run;

data &ZExpandTab(
  keep = SGMNT_TYP_CDE LENGTH BB_UID where = (BB_UID and SGMNT_TYP_CDE ~= 1)
);
merge &ZLineTab &ZLinkTab;
by NGD_UID;
BB_UID = BB_UID_L; output;
BB_UID = BB_UID_R; output;
run;
proc sort data = &ZExpandTab;
by BB_UID;
run;
data &ZExpandTab;
merge &ZExpandTab(in = Base) &ZBBtab;
by BB_UID;
if not Base then LENGTH = 0;
run;

proc summary data = &ZExpandTab nway;
class BB_UID;
var LENGTH;
output out = &OutTab(drop = _type_ _freq_) sum = ;
run;

proc delete data = &ZBBTab &ZLineTab &ZLinkTab &ZExpandTab;
run;
%mend;
