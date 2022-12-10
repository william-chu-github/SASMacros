/* this version must have numeric keys... */


/*
generalised clustering algorithm
- ADJFILE is a complete adjacency file for the "blocks" being clustered.
  It needs to be two-sided: if block1 is adjacent to block2, then
  (block1, block2) and (block2, block1) both need to be in the file.
  Self-adjacencies should be excluded to decrease space used/processing time.
  It has double the number of variables as the number of variables identifying
  a unique "block." One set is the block variables themselves, and the other
  is the adjacency variables. The adjacency variables should have "_ADJ"
  appended to their names. For example, if a PC_CB_UID-CB_UID chunk is to be
  clustered, the file would contain variables PC_CB_UID, CB_UID,
  PC_CB_UID_ADJ, CB_UID_ADJ.
- BLOCKFILE is a list of "blocks" to cluster to their greatest adjacency
  extent, given the adjacencies described by the ADJFILE. It has the
  variables listed in BLOCK.
- BLOCK is a space-separated list of variables identifying the "block." e.g.,
  if PC_CB_UID-CB_UID identifies the building block, then list:
  PC_CB_UID CB_UID. The smallest value of the first variable in the cluster
  will be used as the cluster identifier.
- OUTCLUST is the dataset to which to write the output. It will have
  the variables listed in BLOCK as well as new variable CLUSTERID (which
  will overwrite any variable already existing). It must not be the same as
  BLOCKFILE, lest errors occur due to reading and writing from the same
  file in an SQL step.
- SHOWCOUNT is 0/1 depending on whether the macro should print a status
  update every time an iteration finishes

The macro will create some temporary datasets in WORK:
Z_Cluster_Adj, Z_Cluster_Adds, Z_Cluster_Not_Done
*/


%macro HCluster(AdjFile, BlockFile, Block, OutClust, ShowCount = 1);
%local BlockComma GroupString FirstBlock RenameString RenameReverse MatchString Changed
       NumDone KeyString;


* separate variables with comma for use in SQL steps ;
%let BlockComma = %Separate(&Block);
* need to specify table alias for some SQL steps ;
%let GroupString = %substr(%quote(%Prefix(&Block, %str(, L.))), 3);
* get the first block variable listed and use it to populate cluster IDs ;
%let FirstBlock = %scan(&Block, 1);
%let OrigKey = %Separate(%bquote(%Prefix(%bquote(%Suffix(&Block, %str(%'))), %str(%'))), Separator = %str(, ));
%let KeyString = %Separate(
  %bquote(%Prefix(
    %bquote(%Suffix(
      %Suffix(&Block, _ADJ),
      %str(%')
    )),
    %str(%')
  )),
  Separator = %str(, )
);

* generate the SQL join string for joining the blocks on both sides, and
  generate renaming string at the same time ;
%let RenameString = %Interleave(&Block, %Suffix(&Block, _ADJ));
%let RenameReverse = %Interleave(%Suffix(&Block, _ADJ), &Block);
%let MatchString =
  %Interleave(
    %Prefix(&Block, L.), %Prefix(&Block, Adj.), Separator = %str( and )
  ) and
  %Interleave(
    %Prefix(%Suffix(&Block, _ADJ), Adj.),
    %Prefix(&Block, R.),
    Separator = %str ( and )
  );

proc sql;
* initialise output file ;
create table &OutClust as
  select distinct &BlockComma, &FirstBlock as ClusterID
    from &BlockFile
    order by &BlockComma;
* extract adjacencies of all input blocks ;
create table Z_Cluster_Adj as
  select distinct Adj.*
    from &OutClust L, &AdjFile Adj, &OutClust R
    where &MatchString
    order by &BlockComma;
quit;
run;

* repeat until no cluster IDs have changed -- all clusters have reached
  their maximum extents ;
%let Changed = 0;
%do %until (&Changed = 0);
  proc datasets nolist;
  modify &OutClust;
  rename &RenameString;
  quit;
  run;
  data Z_Cluster_Adds;
  length ClusterID 8.;
  if _n_ = 1
    then
      do;
        declare hash Curr(hashexp: 16, dataset: "&OutClust");
        Curr.defineKey(&KeyString);
        Curr.defineData('ClusterID');
        Curr.defineDone();
        call missing(ClusterID);
      end;
  set Z_Cluster_Adj;
  Curr.find();
  run;
  proc datasets nolist;
  modify &OutClust;
  rename &RenameReverse;
  quit;
  run;
  data Z_Cluster_Adds;
  set Z_Cluster_Adds &OutClust;
  run;

  proc summary data = Z_Cluster_Adds nway missing;
  class &Block;
  var ClusterID;
  output out = Z_Cluster_Adds(drop = _type_ _freq_) min = MinID max = MaxID;
  run;
  proc sql noprint;
  select count(*) into :Changed from Z_Cluster_Adds where MinID ~= MaxID;
  * algorithm can take a while... print updates ;
  %if (&ShowCount)
    %then %put Number of blocks changed this iteration: %trim(&Changed);
  quit;
  run;

  %if (&Changed > 0)
    %then
      %do;
        * update cluster IDs ;
        data &OutClust(drop = Temp MinID);
        length MinID 8.;
        if _n_ = 1
          then
            do;
              declare hash Curr(hashexp: 16, dataset: "Z_Cluster_Adds");
              Curr.defineKey(&OrigKey);
              Curr.defineData('MinID');
              Curr.defineDone();
              call missing(MinID);
            end;
        set &OutClust;
        Temp = Curr.find();
        if Temp = 0 then ClusterID = MinID;
        run;
        proc datasets nolist;
        modify Z_Cluster_Adds;
        drop MaxID;
        rename MinID = ClusterID;
        run;
        data Z_Cluster_Not_Done(drop = Temp);
        length ClusterID 8.;
        if _n_ = 1
          then
            do;
              declare hash Curr(hashexp: 16, dataset: "Z_Cluster_Adds");
              Curr.defineKey(&OrigKey);
              Curr.defineData('ClusterID');
              Curr.defineDone();
              call missing(ClusterID);
            end;
        set Z_Cluster_Adj;
        Temp = Curr.find();
        if Temp = 0 then LClust = ClusterID;
        run;
        proc datasets nolist;
        modify &OutClust;
        rename &RenameString ClusterID = ClusterID_ADJ;
        quit;
        run;
        data Z_Cluster_Not_Done/*(where = (LClust ~= RClust) drop = Temp)*/;
        length ClusterID 8.;
        if _n_ = 1
          then
            do;
              declare hash Curr(hashexp: 16, dataset: "&OutClust");
              Curr.defineKey(&KeyString);
              Curr.defineData('ClusterID_ADJ');
              Curr.defineDone();
              call missing(ClusterID_ADJ);
            end;
        set Z_Cluster_Not_Done;
        Temp = Curr.find();
        if Temp = 0 then RClust = ClusterID_ADJ;
        run;
        proc datasets nolist;
        modify &OutClust;
        rename &RenameReverse ClusterID_ADJ = ClusterID;
        quit;
        run;
        proc sort data = Z_Cluster_Not_Done(keep = &Block) nodupkey; by &Block; run;

        * clusters are done when all adjacencies are within the cluster
          itself -- then adjacency relationships in those blocks can be
          deleted to speed execution ;
        data Z_Cluster_Adj(drop = TempID);
        if _n_ = 1
          then
            do;
              declare hash Curr(hashexp: 16, dataset: "Z_Cluster_Not_Done");
              Curr.defineKey(&OrigKey);
              Curr.defineDone();
            end;
        set Z_Cluster_Adj;
        TempID = Curr.find();
        if TempID = 0;
        run;
      %end;
%end;
* delete temporary work ;
proc delete data = Z_Cluster_Adj Z_Cluster_Adds Z_Cluster_Not_Done; run;
%mend;


/*
proc sql;
create table zbb as
  select bb_uid, bb_uid as bb, da_id
    from wh.wc2016ngd_a_201303 bb, wh.wc2016cb_201303 cb
    where bb.cb_uid = cb.cb_uid and prcode = "13"
    order by bb_uid;
create table zline as
  select bb_uid_l, bb_uid_r from wh.wc2016ngd_al_201303;
quit;
run;
%lineadj(zline, zbb, bb_uid, hclust_adj);
data hclust_adj;
set hclust_adj(rename = (bb = bb_uid bb_adj = bb_uid_adj) where = (da_id = da_id_adj));
run;

options nonotes;

options notes;
options nosymbolgen;
BB_UID in (915572, 1143094)
*/

%let start = %sysfunc(time());
%HCluster(hclust_Adj, zbb, bb_UID, HClusters);
%let end = %sysfunc(time());
%let diff = %sysevalf(&end - &start);
%put &diff;

%let start = %sysfunc(time());
%Cluster(hclust_Adj, zbb, bb_UID , Clusters);
%let end = %sysfunc(time());
%let diff = %sysevalf(&end - &start);
%put &diff;


proc compare data = clusters c = zclusters listvar listequalvar; id bb_uid; run;




