/*
data line;
set wh.wc2021ngd_al_202106(keep= ngd_uid bb_uid_l bb_uid_r);
run;
proc sql;
create table bb as
  select bb_uid, bb_uid as bb, bb.cb_uid, cb.prcode
    from wh.wc2021ngd_a_202106 bb, wh.wc2021cb_202106 cb
    where bb.cb_uid = cb.cb_uid;
quit;
run;
%lineadj(line, bb, bb_uid, adj);
data adj(rename = (bb = bb_uid bb_adj = bb_Uid_adj));
set adj(where = (prcode = prcode_adj));
run;

%Timer(Init = 1, Message = %str(starting old clustering));
%cluster(adj, bb, bb_uid, old);
%Timer(Message = %str(ending old clustering));

* ending old clustering 862.994999885559 ;
*/

* !!! needs to be extended to multivariable block ID ;
* variable mangling, dataset name mangling... ;
* need to add in blocks that are not in the adjacency file ;
%macro NewCluster(AdjFile, BlockFile, Block, OutClust, ShowCount = 1);
proc sql;
create table &OutClust as
  select distinct &Block, &Block._Adj
    from &AdjFile
    where &Block < &Block._Adj
    order by &Block, &Block._Adj;
* add in blocks that are not represented in the adjacency file ;
/*create table &OutClust as
  select * from &OutClust union
  select &Block, &Block as &Block._Adj
    from (select &Block from &BlockFile except
           (select &Block from (select &Block from &AdjFile union select &Block._Adj from &AdjFile))
         );*/
quit;
run;
data &OutClust;
set &OutClust;
RowID = _n_;
ClusterID = min(&Block, &Block._Adj);
run;

%local UnchangedIterations CurrVar OtherVar ChangedRecs;
%let UnchangedIterations = 0;
%let CurrVar = &Block;
%let OtherVar = &Block._Adj;
%do %while (&UnchangedIterations ~= 2);
  proc sql;
  create table Z_Cluster_Update1 as
    select RowID, &CurrVar, min(ClusterID) as ClusterID
      from &OutClust
      group by &CurrVar
      order by RowID;
  create table Z_Cluster_Update2 as
    select distinct B.RowID, A.ClusterID
      from Z_Cluster_Update1 A join &OutClust B
      on A.&CurrVar = B.&OtherVar
      order by RowID;
  create table Z_Cluster_Update as
    select coalesce(A.RowID, B.RowID) as RowID,
           case
             when (A.RowID is missing) then B.ClusterID
             when (B.RowID is missing) then A.ClusterID
             else min(A.ClusterID, B.ClusterID)
           end as ClusterID
      from Z_Cluster_Update1 A full join Z_Cluster_Update2 B
      on A.RowID = B.RowID
      order by RowID;
  quit;
  run;
  proc compare data = &OutClust c = Z_Cluster_Update out = Z_Cluster_Diff outnoequal noprint;
  id RowID;
  var ClusterID;
  run;
  %let ChangedRecs = %CountObs(Z_Cluster_Diff);
  %if (&ChangedRecs)
    %then
      %do;
        data &OutClust;
        update &OutClust Z_Cluster_Update(keep = RowID ClusterID);
        by RowID;
        run;
        /*
        * also need to change the block-cluster relationship on the other side ;
        proc sql;
        create table Z_Cluster_Update as
          select distinct B.RowID, A.ClusterID
            from Z_Cluster_Update A join &OutClust B
            on A.&CurrVar = B.&OtherVar
            order by RowID;
        quit;
        run;
        data &OutClust;
        update &OutClust Z_Cluster_Update(keep = RowID ClusterID);
        by RowID;
        run;
        */
      %end;
  %if (&ShowCount)
    %then
      %do;
        %put Cluster changed ClusterID of %trim(&ChangedRecs) this iteration;
      %end;
  %if (&ChangedRecs = 0)
    %then %let UnchangedIterations = %eval(&UnchangedIterations + 1);
    %else %let UnchangedIterations = 0;
  %if (&CurrVar = &Block)
    %then %do; %let CurrVar = &Block._Adj; %let OtherVar = &Block; %end;
    %else %do; %let CurrVar = &Block; %let OtherVar = &Block._Adj; %end;
%end;
/*
data z_back;
set &outclust;
run;
*/

* !!! need to put in blocks that are not in the adjacency file ;
proc sql;
create table &OutClust as
  select &Block, ClusterID from &OutClust union
  select &Block._Adj as &Block, ClusterID from &OutClust
  order by &Block;
* add in blocks that are not represented in the adjacency file ;
create table &OutClust as
  select * from &OutClust union
  select &Block, &Block as &Block._Adj
    from (select &Block from &BlockFile except
           (select &Block from (select &Block from &AdjFile union select &Block._Adj from &AdjFile))
         );
quit;
run;
%mend;

%Timer(Init = 1, Message = %str(starting new clustering));
options nonotes;
%newcluster(adj, bb, bb_uid, new);
options notes;
%Timer(Message = %str(ending new clustering));
*ending new clustering 982.472999811172 ;
* the adjacency correction approx doubles the time from 480 to 980 ;

* is it possible for two-name updated scheme to cause an infinite loop? ;

/*

%compareuniverse(old, bb, bb_uid);
%compareuniverse(new, bb, bb_uid);

proc sql;
create table z as
  select distinct bb_uid, clusterid
    from new
    group by bb_uid
    having count(distinct clusterid) > 1;
quit;
run;



data zz;
set z_back(where = (bb_uid in (26915, 26916) or bb_uid_adj in (26915, 26916)));
run;


proc sql;
create table z as
  select old.bb_uid, old.clusterid as old, new.clusterid as new
  from old, new
where old.bb_uid = new.bb_uid;
quit;
run;
%nton(z, old, new, zrel);
proc freq data = zrel; tables relationshipnn; run;

proc compare data = old c = new listvar listequalvar; id bb_Uid; run;
*/

/*
proc export data = adj outfile = "c:\docs\download\adj.csv" replace; run;
proc export data = bb outfile = "c:\docs\download\bb.csv" replace; run;

*/

/*
rowid block adj cluster
1     1     2   1
2     2     3   2

*/


/*
proc import datafile = "c:\docs\temp\pandas_clusters.csv" out = pandas replace; run;
proc sort data = pandas; by bb_Uid; run;

proc compare data = old c = pandas(rename = (unique_id = clusterid)) listvar listequalvar;
id bb_uid;
run;
*/
