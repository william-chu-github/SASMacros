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
  will be used as the cluster identifier. This can cause issues if there are odd
  overlapping relationships between the identifiers, such that the first variable
  can have the same identifier value over noncontiguous clusters. Therefore, it is
  recommended that a composite key of all the variables be constructed and input as
  the first variable, to guarantee uniqueness of the output ClusterID.
- OUTCLUST is the dataset to which to write the output. It will have
  the variables listed in BLOCK as well as new variable CLUSTERID (which
  will overwrite any variable already existing). It must not be the same as
  BLOCKFILE, lest errors occur due to reading and writing from the same
  file in an SQL step.
- SHOWCOUNT is 0/1 depending on whether the macro should print a status
  update every time an iteration finishes

The macro will create some temporary datasets in WORK:
Z_Cluster_Adj, Z_Cluster_Adds, Z_Cluster_Done
*/
%macro Cluster(AdjFile, BlockFile, Block, OutClust, ShowCount = 1);
%local BlockComma GroupString FirstBlock RenameString MatchString Changed
       NumDone;
* separate variables with comma for use in SQL steps ;
%let BlockComma = %Separate(&Block);
* need to specify table alias for some SQL steps ;
%let GroupString = %substr(%quote(%Prefix(&Block, %str(, L.))), 3);
* get the first block variable listed and use it to populate cluster IDs ;
%let FirstBlock = %scan(&Block, 1);

* generate the SQL join string for joining the blocks on both sides, and
  generate renaming string at the same time ;
%let RenameString = %Interleave(&Block, %Suffix(&Block, _ADJ));
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
  select Adj.*
    from &OutClust L, &AdjFile Adj, &OutClust R
    where &MatchString
    order by &BlockComma;
quit;
run;

* repeat until no cluster IDs have changed -- all clusters have reached
  their maximum extents ;
%let Changed = 0;
%do %until (&Changed = 0);
  proc sql noprint;
  * for each block, calculate the minimum and maximum cluster IDs of
    adjacent blocks, including the self-intersections ;
  create table Z_Cluster_Adds(drop = TheMin TheMax) as
    select distinct &GroupString, min(R.ClusterID) as TheMin,
           max(R.ClusterID) as TheMax,
           case
             when (L.ClusterID <= calculated TheMin) then L.ClusterID
             else calculated TheMin
           end as MinID,
           case
             when (L.ClusterID >= calculated TheMax) then L.ClusterID
             else calculated TheMax
           end as MaxID
      from &OutClust L, Z_Cluster_Adj Adj, &OutClust R
      where &MatchString
      group by &GroupString
      order by &BlockComma;
  * if the min/max are not equal, then the cluster can be
    extended... arbitrarily put it into the cluster with the minimum
    cluster ID, to make the algorithm deterministic ;
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
        data &OutClust;
        update
          &OutClust
          Z_Cluster_Adds(drop = MaxID rename = (MinID = ClusterID))
        ;
        by &Block;
        run;
        proc sql noprint;
        * clusters are done when all adjacencies are within the cluster
          itself -- then adjacency relationships in those blocks can be
          deleted to speed execution ;
        create table Z_Cluster_Done as
          select distinct &GroupString
            from &OutClust L, Z_Cluster_Adj Adj, &OutClust R
            where &MatchString
            group by L.ClusterID
            having sum(L.ClusterID ~= R.ClusterID) = 0
            order by &BlockComma;
        select count(*) into :NumDone from Z_Cluster_Done;
        quit;
        run;
        %if (&NumDone > 0)
          %then
            %do;
              * delete base side ;
              data Z_Cluster_Adj;
              merge Z_Cluster_Adj Z_Cluster_Done(in = Del);
              by &Block;
              if not Del;
              run;
            %end;
      %end;
%end;
* delete temporary work ;
proc delete data = Z_Cluster_Adj Z_Cluster_Adds Z_Cluster_Done; run;
%mend;
