[TOC]

# SAS Macros

A collection of SAS macros useful for my work. A lot of the SAS scripts I write will expect these macros to be available.

In addition, much of my work expects connectivity with databases like WAREHOUSE on GEODEPOT. Thus, before running any of my programs, ensure these libraries are active in SAS:

    libname WH oracle path = GEODEPOT.GEO.STATCAN.CA
      schema = WAREHOUSE user = CHUWILL dbprompt = yes access = readonly sqlgeneration = none DIRECT_SQL = none;
    libname CCPS oracle path = GEODEPOT.GEO.STATCAN.CA
      schema = CCPS user = CCPS dbprompt = yes access = readonly sqlgeneration = none DIRECT_SQL = none;


# Installation

If you use macros from other sources, it's possible some of my macro names will clash with them. I'm unaware of a good way to resolve these sorts of conflicts in SAS, which doesn't have an analogue to Python's package namespaces.

## PC/Linux SAS

1. From the [repository page](https://gitlab.k8s.cloud.statcan.ca/chuwill/sas-macros), download the files in ZIP format.
1. Unzip to a local directory.
1. Either:
    - Edit the sas.cfg file to include that directory on startup. For example, if I unzipped into %userprofile%\documents\SAS_Code\Macros, I would make sure to include that directory in the SASAUTOS parameter:

            -SET SASAUTOS (
                "!SASROOT\core\sasmacro"
                "!SASROOT\aacomp\sasmacro"
                "!SASROOT\accelmva\sasmacro"
                "!SASROOT\dmscore\sasmacro"
                "!SASROOT\ets\sasmacro"
                "!SASROOT\gis\sasmacro"
                "!SASROOT\graph\sasmacro"
                "!SASROOT\hps\sasmacro"
                "!SASROOT\iml\sasmacro"
                "!SASROOT\inttech\sasmacro"
                "!SASROOT\lasreng\sasmacro"
                "!SASROOT\mlearning\sasmacro"
                "!SASROOT\or\sasmacro"
                "!SASROOT\qc\sasmacro"
                "!SASROOT\share\sasmacro"
                "!SASROOT\stat\sasmacro"
                "%userprofile%\documents\SAS_Code\Macros"
            )

    * or,
    * At the beginning of the SAS session, execute `options append=(sasautos=("C:\Users\chuwill\Documents"));`. (Substitute appropriate directory.) This does not work if it is not executed at the **beginning** of the session.

## Enterprise Guide

* At the beginning of the SAS session, execute `options append=(sasautos=("C:\Users\chuwill\Documents"));`. (Substitute appropriate directory.) This does not work if it is not executed at the **beginning** of the session.
* or,
* Go to Tools->Options->SAS Programs, check "Submit SAS code when server is connected", edit this in with appropriate directory:

    filename mymacros "C:\Users\chuwill\Documents\SAS_Code\Macros";
    options mautosource sasautos = (mymacros sasautos);

# Usage

## %assignprop(...)

This is a macro used for a deprecated recurring process, assigning proportionally via structure constraints. Saved for possible use in the future.

## %assignproportional(ParentTable, ChildTable, OutDS, ParentIDs, ChildIDs, Vars, ProportionVar, Method)

Macro that assigns variables of a parent level proportionally to rows in the parent level.

* `ParentTable`: input dataset of parent items, where some variables, `Vars`, need to be allocated
  proportionally to child items... columns must include the PARENTIDS... must be unique and sorted
  by `ParentIDs``
* `ChildTable`: input dataset of child items... for each `ParentIDs`, their `Vars` will be divided
  proportionally among the rows of the child table... `ChildTable` must include columns
  `ParentIDs` and `ProportionVar`... the rows of the child table should not overlap, or
  double-counting will happen in the allocation steps (e.g., if the parents are current
  CUs, and the children are PC_CBs, then the rows of the child table should be the sum of
  the BBs in both the PC_CB and CC_CU)
* `OutDS`: output dataset
* `ParentIDs`: space-separated list of variables that identifies the parent level
* `ChildIDs`: space-separated list of variables that identifies the child level, used solely
  for deterministic sorting of results... can pass in a null value to ignore
* `Vars`: space-separated list of variables in the parent table to allocate proportionally
* `ProportionVar`: the variable on the child input file to be used to calculate proportions...
  the variable is summed up over the `ParentIDs`, and each input row has a certain percentage
  of this total... that percentage of each variable in `Vars` is assigned to the row...
  the expectation is that each PARENTID will a nonzero sum of PROPORTIONVAR--otherwise proportions
  cannot be assigned, because there are no data--in this case, the macro will halt with an error
* `Method`:
    * 0 = no rounding (probably not suitable for integer-valued items like pop or dwelling counts)
    * 1 = round top x: rounded to nearest integer (banker's rounding), then after sorting by
      descending variable value and ascending child IDs, modify the top few records by +/- 1
      per parent IDs to ensure the sum of the rounded values equals the input value at the
      parent ID value
      e.g., if three child records were allocated 9, 8, 5, but the total parent sum was 24,
      the allocation lost two items due to rounding... this option would add one item to the
      9 and 8 counts for a final allocation of 10, 9, 5, summing to the original 24
    * 2 = adjust max value of parent group (after sorting by descending variable value and
      ascending child IDs) to ensure sum of output equals sum of input at the parent level
      e.g., repeating the above 9, 8, 5 example, this option only adjusts the top record, and
      the final allocation is 11, 8, 5

Example:

    data da;
    infile datalines;
    input da_uid da_pop da_dwell;
    datalines;
    1 50 15
    ;
    run;
    data disb;
    infile datalines;
    input da_uid block proportion;
    datalines;
    1 1 0.5 0.3
    1 2 0.3 0.1
    1 3 0.2 0.1
    1 4 0   0.2
    1 5 0   0.3
    ;
    run;
    %assignproportional(da, disb, alloc, da_uid, da_uid block, da_pop da_dwell, proportion, 1);

yields:
    
    Input DA
    Obs    da_uid    da_pop    da_dwell

    1        1        50         15

    Input DISB
    Obs    da_uid    block    proportion

    1        1        1          0.5
    2        1        2          0.3
    3        1        3          0.2
    4        1        4          0.0
    5        1        5          0.0

    Output
    Obs    da_uid    block    da_pop    da_dwell

    1        1        1        25          8
    2        1        2        15          4
    3        1        3        10          3
    4        1        4         0          0
    5        1        5         0          0

The output has allocated roughly 50%/30%/20% of the counts to the blocks with nonzero proportions.

## %cluster(AdjFile, BlockFile, Block, OutClust, ShowCount = 1, ClusterID = ClusterID)

In many cases, it's useful to aggregate polygons that are adjacent to one other until
no more adjacencies are found. For example, when delineating mailout, it's useful to analyse
contiguous clusters of blocks that are all in mailout.

- `AdjFile` is a complete adjacency file for the "blocks" being clustered.
  It needs to be two-sided: if block1 is adjacent to block2, then
  (block1, block2) and (block2, block1) both need to be in the file.
  Self-adjacencies should be excluded to decrease space used/processing time.
  It has double the number of variables as the number of variables identifying
  a unique "block." One set is the block variables themselves, and the other
  is the adjacency variables. The adjacency variables should have "_ADJ"
  appended to their names. For example, if a PC_CB_UID-CB_UID chunk is to be
  clustered, the file would contain variables PC_CB_UID, CB_UID,
  PC_CB_UID_ADJ, CB_UID_ADJ.
- `BlockFile` is a list of "blocks" to cluster to their greatest adjacency
  extent, given the adjacencies described by the ADJFILE. It has the
  variables listed in BLOCK.
- `Block` is a space-separated list of variables identifying the "block." e.g.,
  if PC_CB_UID-CB_UID identifies the building block, then list:
  PC_CB_UID CB_UID. The smallest value of the first variable in the cluster
  will be used as the cluster identifier. This can cause issues if there are odd
  overlapping relationships between the identifiers, such that the first variable
  can have the same identifier value over noncontiguous clusters. Therefore, it is
  recommended that a composite key of all the variables be constructed and input as
  the first variable, to guarantee uniqueness of the output ClusterID. Note also there is degradation
  in performance if there are many variables specified in `Block`. See %createcompositekeys for
  a way to simplify complex keys.
- `OutClust` is the dataset to which to write the output. It will have
  the variables listed in `Block` as well as new variable CLUSTERID (which
  will overwrite any variable already existing). It must not be the same as
  `BlockFile`, lest errors occur due to reading and writing from the same
  file in an SQL step.
- `ShowCount` is 0/1 depending on whether the macro should print a status
  update every time an iteration finishes
- `ClusterID` is the variable name to use to label clusters uniquely.

Example test data:

    data adj;
    input block block_adj parent parent_adj;
    datalines;
    1 2 10 10
    2 1 10 10
    2 3 10 11
    3 2 11 10
    ;
    run;
    data block;
    input block;
    datalines;
    1
    2
    3
    ;
    run;

Here, since the three blocks are contiguous according to the adjacency relationships (block 1 is adjacent to block 2 and block 2 is adjacent to block 3), the macro assigns the same CLUSTERID to all blocks.

    %cluster(adj, block, block, clusterfile);

                    Cluster
    Obs    block       ID

    1       1         1
    2       2         1
    3       3         1

However, if we restrict adjacencies to blocks within the same parent, block 3 ends up in its own cluster, since it is not in the same parent as blocks 1 and 2:

    %cluster(adj(where = (parent = parent_adj)), block, block, clusterfile);

                    Cluster
    Obs    block       ID

    1       1         1
    2       2         1
    3       3         3

## %compareuniverse(DS1, DS2, ID, OutDS =)

Given two datasets of universes of unique IDs, either print a list of the
first 10 mismatched IDs, or create a dataset of all mismatched IDs.

* `DS1`, `DS2` are the two datasets to compare.
* `ID` is a space-separted list of unique ID keys.
* `OutDS`, when blank, prints the first ten mismatched; when non-blank, outputs
  all mismatched to the specified dataset.
* Output variables are the keys suffixed with "_1" or "_2", depending on whether they were extracted from the first or second dataset.

      data ds1;
      do i = 3 to 7;
      output;
      end;
      run;
      data ds2;
      do i = 5 to 9;
      output;
      end;
      run;
      %compareuniverse(ds1, ds2, i);

prints a selection of unique IDs that are not in both input datasets:

        i_1       i_2
    ------------------
                    8
                    9
        3
        4


## %countobs(DS)

Returns the number of observations in the given dataset as macro text. Executing:

    data z;
    do i = 1 to 10;
    output;
    end;
    run;

    %put number of records: %countobs(work.z);

writes this to the log:

    number of records: 10

## %createcompositekeys(Adj, Block, Vars, KeyName = CompositeKey)

In many operations, a unique identifier is make up of multiple string variables which have to be concatenated. In extreme cases, the concatenation result is very long, and applied over all rows of the dataset, makes the dataset larger than necessary, which slows down processing and merging. This macro maps unique combinations of variables with a numeric, sequential integer to improve performance.

Written for use with %cluster, though it can be used for other purposes.

* ADJ is the input adjacency file, which will be overwritten (can prevent overwriting permanent files by copying and calling with the copy)
* BLOCK is the input block file
* VARS is the space-separated list of variable names which identify the "block" of a cluster
* KEYNAME is the variable name to use for the composite key
* BLOCK dataset is unduplicated by the block variables, and then a sequential integer KEYNAME variable is added, identifying unique combinations of blocks
* ADJ dataset is edited to include KEYNAME and KEYNAME_ADJ according to the calculation in the BLOCK dataset, and unduplicated on all variables
* %cluster can then be called with the ADJ and BLOCK, and the results can be related back to the true blocks using variables on the BLOCK file

For example, running this:

    data blockfile;
    infile datalines;
    input prcode $ cdcode $;
    datalines;
    10 01
    10 01
    10 02
    10 03
    10 03
    ;
    run;
    data adjfile;
    infile datalines;
    input prcode $ cdcode $ prcode_adj $ cdcode_adj $;
    datalines;
    10 01 10 02
    10 02 10 01
    10 02 10 03
    10 03 10 02
    ;
    run;

    %CreateCompositeKeys(adjfile, blockfile, prcode cdcode, KeyName = CompositeKey);

will yield updated block and adjacency files:

                            Composite
    Obs    prcode    cdcode       Key

    1       10        01          1
    2       10        02          2
    3       10        03          3


        Composite    Composite                        prcode_    cdcode_
    Obs       Key        Key_ADJ     prcode    cdcode      adj        adj

    1         1            2          10        01        10         02
    2         2            1          10        02        10         01
    3         2            3          10        02        10         03
    4         3            2          10        03        10         02


## %deformat(Libs = , Tabs = , SuppressLogNotes = 1)

Strip all formatting from libraries `Libs` and tables `Tabs`. Both parameters are space-separated lists of text.

`SuppressLogNotes`: 1 to suppress log notes when deformatting, or 0 to allow ;

Useful for shortening PROC COMPARE outputs.

## %englishfrenchrenames(DS)

Given a translation dataset from French to English, rename variables in `DS` from French variable names to English variable names. Useful for QA of datasets which must be produced in both official languages.

The translations in the macro should not be considered complete, since only a subset of tables are disseminated. Translations not included in the macro would leave the original column names unmodified.

By default, accented variable names are not allowed in SAS. Some of the QA work requires these; `options validvarname = any;` can be used to allow accents.

E.g., 

    data ds;
    ididu = 4;
    run;
    %EnglishFrenchRenames(ds);

renames the French IDIDU (dissemination block) to the English version:

    Obs    DBUID

    1       4

## %errorout(DS, MSG)

Macro that stops SAS processing and prints an error message to the log if it is passed in
a dataset that has more than zero rows (which it will print the first ten records). Useful for
QA flow that outputs a dataset of critical errors--if the dataset is nonempty, errors occurred and
the process should be halted.

## %finddupkeys(DS = _last_, Key = , OutDS = , PrintObs = 0)

Find duplicate keys in an input dataset.

* `DS`: input dataset in which to search for duplicate keys
* `Key`: the search key for which there should be no duplicates
* `OutDS`: output dataset to save keys with a count > 1
* `PrintObs`: number of observations to print if there are counts > 1

Example run:

    data ds;
    infile datalines;
    input i;
    datalines;
    1
    1
    2
    3
    2
    4
    5
    6
    ;
    run;

    %finddupkeys(ds = ds, key = i, outds = dups, printobs = 5);

prints:

    Obs    i    Count

    1     1      2
    2     2      2


## %findweirdchars(Tab, OutDS)

Given an input dataset `Tab`, loop through all character variables. Output to `OutDS`
"weird" characters found in those variables. Alphanumeric characters (after stripping common accents)
are ignored, as are common punctuation.

In the past, this macro has found things such as embedded newlines and nonstandard hyphenation (e.g., using an emdash or endash instead of an ASCII hyphen).

## %getnewdsnames(Library = WORK, NumNames = 1, NotAllowed = %str())

Given a `Library`, return `NumNames` dataset names which do not exist in the library--for
ensuring no dataset overwriting.

`NotAllowed` is a space-separated list of names which are not allowed, useful for
disallowing specified datasets that are not yet created.
E.g., user specifies dataset abc as output, but does not exist... passing in
`NotAllowed` = ABC ensures ABC is not returned as a possible allowable name ;

Returns a space-separated list and does not include a library reference ("libname.").
The list can then be parsed/separated to create new, nonclashing datasets in the specified library.

    %put %getnewdsnames(Library = WORK, NumNames = 4, NotAllowed = ds1);

assuming NEWDS1 and NEWD2S already exist in WORK, writes to the log:

    NEWDS3 NEWDS4 NEWDS5 NEWDS6

## %getnewvarnames(DS, NumNames = 1, Exclusions = %str())

Utility macro that gives new variable names that are not in the input dataset `DS`.
Useful for ensuring no name collisions in macro code.

`NumNames` is the number of variables to create (will be of pattern NEWNAME<number>) ;

`Exclusions` is a space-separated list of names not to use, which are not already in the dataset...
useful in case variables with specific names must be added to the dataset later.

E.g.,

    data ds;
    newname1 = 1; newname2 = 2;
    run;
    %put %getnewvarnames(ds, numnames = 2);

prints:

    NEWNAME3 NEWNAME4

since NEWNAME1, NEWNAME2 already exist in the target dataset.

## %getvarnames(DS)

Generates the complete list of column names in a SAS dataset `DS` and
returns it as a macro string of space-separated values.

## %interleave(List1, List2, Interleaver = %str( = ), Separator = %str( ))

Generate a component-wise list of x_n = y_n given two input lists x and y.
Assumes the two input lists are space-separated, and of the same length
(word-wise). e.g., `%Interleave(a b c, 1 2 3)` will return a macro string of `a = 1 b = 2 c = 3`
The major application for this macro would be generating RENAME = strings
in data steps, or join strings in SQL steps. Works as a function--use only in macro code.

The additional parameters `Interleaver` and `Separator` can be left alone to
generate rename strings, but can be filled in to generate more complicated
interleavings. `Interleaver` is the sequence of characters that will be inserted
between the respective components of the `List1` and `List2`. `Separator` is the
sequence of characters that will be inserted after each interleaved pair except
the last.

    %Interleave(
      BB.CB_UID CB.PRCODE||CB.CDCODE||CB.CSDCODE,
      CB.CB_UID CSD.CSD_UID,
      Interleaver = %str( = ), Separator = %str( and )
    );

yields

    BB.CB_UID = CB.CB_UID and CB.PRCODE||CB.CDCODE||CB.CSDCODE = CSD.CSD_UID

Note that the first list argument with the concatenations above cannot have
spaces between the pipes, as they would be interpreted as different components
of the list.

## %lineadj(Line, Poly, Block, Out, Static = %str(), Self = 0, Keep0 = 0, SelfExpand = %str())

Helper that creates an adjacency file based on line adjacencies (i.e., NGD_AL),
given a "line" input file, and a polygon file linking the line "blocks" to the
geographic level of interest. This macro is therefore not appropriate for
pointwise adjacencies or overlapping adjacencies (PC_CB:CB clustering).

- `Line` is the dataset detailing the basic left/right block relationship of
  the line objects. It must contain two variables: the value of `Block` with
  "_R" appended, and with "_L" appended. e.g., BB_UID_L, BB_UID_R.
- `Poly` is the dataset linking the blocks of the line file to the higher
  geography whose adjacency relationships are required. The BLOCK variable
  must be in this dataset. Every other variable in the dataset is assumed to
  be a part of the unique identifier of the higher geography of interest.
- `Block` is the unique ID variable for the block that is affiliated with
  the `Line` and `Poly` files. Only one variable is allowed; the unique ID
  cannot be a combination of multiple variables for this macro.
- `Out` is the output dataset to write the adjacency relationships. An existing
  file will be overwritten, and specifying the same file as `Line` or `Poly`
  will probably result in an error. Based on the `Line` and `Poly` inputs, the
  output file will list all higher geographic adjacencies. Self-adjacencies
  are excluded, as are adjacencies that are outside of the universe covered
  by the `Line` file (e.g., polygon 0, or the national boundary). The adjacencies
  output will be two-sided; if X-adjacent-to-Y is in the file, then so is
  Y-adjacent-to-X. The output variables will be all of the non-`Block` variables
  from `Poly`, and the same variables with "_ADJ" appended (e.g., DA_UID,
  DA_UID_ADJ). Consequently, if there are existing variables on the input data
  named <x> and <x>_ADJ, the results may be corrupted, since the macro will try
  to create a new variable <x>_ADJ, overwriting the source <x>_ADJ value.
  The sort order will be the non-ADJ variables, then the ADJ ones.
- `Static` is a space-separated list of variables in the `Line` dataset to keep
  (e.g., a length variable for perimeter analysis, or an ID variable).
- `Self` is 0/1; set to 1 if the link level is the actual one in the line layer
  and there is no need to merge.
- `Keep0` is 0/1; set to 1 to keep arcs with non-"true" values on either the
  right or left side (e.g., national borders with CB_UID_R/L equal to zero).
- `SelfExpand` is a space-separated list of L/R attributes in the line table
  itself; these are to be expanded into adjacency relationships in the
  output. Do not include the _L/_R tags.

Example usage:

    data line;
    infile datalines;
    input id bb_uid_l bb_uid_r;
    datalines;
    1 1 2
    2 2 3
    ;
    run;
    data block;
    infile datalines;
    input bb_uid;
    datalines;
    1
    2
    3
    4
    ;
    run;
    %lineadj(line, block, bb_uid, adj);

produces:

                    bb_uid_
    Obs    bb_uid      ADJ

    1        1         2
    2        2         1
    3        2         3
    4        3         2

Notice block 4 is not present, since it has no relationships in the input line file.

## %log(Message)

Writes a message to the log, with a timestamp.

## %measuredb(InTab, OutTab, ID, Type = A, DB = GEODEPOT.GEO.STATCAN.CA, Schema = WAREHOUSE, User = CHUWILL)

Macro to lift unique ID and internal area/length value from a spatial table.

* `InTab` is the table name under the `Schema` (defaults to WAREHOUSE)
  on the database `DB` (defaults to GEODEPOT.GEO.STATCAN.CA)
* `OutTab` is the table in WORK to which to write the `ID` and area (`Type` is A) or length (`Type` is L) variables.
* `User` is a user who has access to the schema (defaults to CHUWILL)--
  a password prompt will appear
* `Type` (AREA or LENGTH) determines whether the macro downloads area or length--
  defaults to AREA

## newcluster

Alternative implementation of %cluster to see if can be sped up; development incomplete.

## %nton(Blocks, ID1, ID2, Out, RelationshipVar = RelationshipNN)

Macro that takes the polygon overlap relationships of two geographic
hierarchies in an input file and outputs whether they are 1:1, 1:n, n:1, or n:n.

- `Blocks` is the input SAS dataset. It must have the variables listed in `ID1` and
  `ID2`. It completely lists the distinct block-to-block relationships.
- `ID1` is the space-separated list of variables from BLOCKS that uniquely
  identifies the first geography.
- `ID2` is the list of variables that uniquely identifies the second geography.
- `Out` is the file to which to write the output. Variables included will be those
  listed in `ID1` and `ID2`, plus `RelationshipVar`, which is the relationship type
  of the ID1 block to the ID2 block for the record. It also includes `ID2Count`
  (the number of `ID2` "blocks" the ID1 "block" key overlaps) and `ID1Count`
  (the number of `ID1` "blocks" the ID2 "block" key overlaps).
  `Out` is a relationship-level output file, so IDs which are split will occur
  multiple times. Although `Blocks` can probably be the same as `Out`, overwriting
  is not recommended.
- `RelationshipVar` names the variable to output the relationship type (1:1, ...).

Example run:

    data blocks;
    infile datalines;
    input parent child;
    datalines;
    1 10
    1 11
    2 12
    3 13
    4 14
    4 15
    5 16
    5 17
    6 16
    6 17
    ;
    run;
    %nton(blocks, parent, child, rels);

produces a dataset rels:

                                                      Relationship
    Obs    parent    child    ID2Count    ID1Count         NN

      1       1        10         2           1           1:n
      2       1        11         2           1           1:n
      3       2        12         1           1           1:1
      4       3        13         1           1           1:1
      5       4        14         1           2           n:1
      6       5        16         2           2           n:n
      7       5        17         2           2           n:n
      8       6        16         2           2           n:n
      9       6        17         2           2           n:n
     10       7        14         1           2           n:1



## %prefix(List, Prefix)

Given a space-separated list of words, return macro text with those words prefixed with `Prefix`. Useful as an aid to programmatically generate SQL joins.

    %put %prefix(a b c, %str(prefix.));

prints to log:

    prefix.a prefix.b prefix.c

## %readjson(File, OutDS, LibName)

Reads a JSON file. Used mainly to read the datatable extracted from a file-based spatial format
exported from geopandas. Assumption is the file is encoded in the same encoding as SAS (generally,
Windows Latin 1).

* `File` is the path + name + extension of the JSON file. A map file will be created (same file, with
  additional ".map" appended) to enable SAS to read the data.
* `OutDS` is the dataset to which to write the parsed data.
* `LibName` is a library name to give to the JSON file. Deassigned after reading the file.

## %readxml(File, OutDS, LibName)

Reads an XML file. Used mainly to read the datatable extracted from a file-based spatial format
exported from geopandas. Assumption is the file is encoded in the same encoding as SAS (generally,
Windows Latin 1).

* `File` is the path + name + extension of the XML file. A map file is also expected (same file, with
  additional ".map" appended) to enable SAS to read the data.
* `OutDS` is the dataset to which to write the parsed data.
* `LibName` is a library name and file reference to give to the XML file. Deassigned after reading the file.

## %rebalance(InDS, OutDS, SourceVars, RebalVars, LevelVars)

Macro that adjusts numeric allocations so they sum up to originals at a
given level. No guarantee is given that the final results will be
non-negative, so it is safest to round down in an allocation where
fractions are possible. The first "block" of a level will be adjusted
to have the total sum of the blocks' allocations equal to the original
input level. Thus it is beneficial to have the block with the largest
allocation listed first, to yield the least percentage change. Thus the
this macro may not be suitable if there are multiple variables being
rounded, and the "biggest" block is different for each variable.

- `InDS` is the input dataset. It must be sorted by `LevelVars`. It must
  have the numeric variables listed in `SourceVars` and `RebalVars`. The values
  in `RebalVars` are record-level values (e.g., dwellings assigned to the
  portion of the DA in that record), whereas the values in `SourceVars`
  are geo-level values (e.g., the number of dwellings in the DA) and
  are therefore constant over the parent geography.
- `OutDS` is the output dataset, which will be the same as the input one,
  but with allocation variables nudged to sum to expected totals. If `InDS`
  is the same as `OutDS`, it will be overwritten.
- `SourceVars` is a space-separated list of the original values
  of the variables at the parent level.
- `RebalVars` is a space-separted list of the allocated, rounded
  values. These are the variables that must add up to the `SourceVars` at
  the parent level.
- `LevelVars` is a space-separated list of the parent geographic level whose
  summed allocation values are to be maintained.

Example:

    data alloc;
    infile datalines;
    input da_uid block da_pop da_dwell alloc_pop alloc_dwell;
    datalines;
    1 1 50 15 15 3
    1 2 50 15 15 4
    1 3 50 15 15 6
    1 4 50 15 3  1
    1 5 50 15 3  1
    ;
    run;


    %Rebalance(alloc, alloc2, da_pop da_dwell, alloc_pop alloc_dwell, DA_UID);

changes the inputs, which had ALLOC_POP summing to 51 (over the 50 DA_POP at the DA level), but leaves ALLOC_DWELL alone, since it summed to the correct value.

                                                    alloc_    alloc_
    Obs    da_uid    block    da_pop    da_dwell      pop      dwell

    1        1        1        50         15         15         3
    2        1        2        50         15         15         4
    3        1        3        50         15         15         6
    4        1        4        50         15          3         1
    5        1        5        50         15          3         1


                                                    alloc_    alloc_
    Obs    da_uid    block    da_pop    da_dwell      pop      dwell

    1        1        1        50         15         14         3
    2        1        2        50         15         15         4
    3        1        3        50         15         15         6
    4        1        4        50         15          3         1
    5        1        5        50         15          3         1


The parent geographic level is DA_UID. The objective is to adjust the
first occurrence of each DA_UID so that the sum of ALLOC_POP and ALLOC_DWELL
in every DA is equal to the listed values of POP and DWELL. No guarantee is
given that the allocation will yield only non-negative values, so it would
be beneficial to have the input dataset sorted by DA_UID and descending size.


## %routelengthkm(LineTab, LinkTab, BBTab, OutTab, DB = GEODEPOT.GEO.STATCAN.CA, Schema = WAREHOUSE, User = CHUWILL)

Macro that calculates BB-level routelength (km) given specified tabular/DB
parameters. Routelength here doesn't consider having to double-back. It only counts the total amount of road in each block. Roads internal to a block are therefore counted twice; once per side of the road.

- `LineTab` is the NGD_AL table
- `LinkTab` is the NGD_AL_TO_A_LINK table
- `BBTab` is the NGD_A table
- `OutTab` is the output file to which to write; it will have columns BB_UID
  (forming a complete set of BBs found on the BB input table) and
  LENGTH (length of non-BOs in km)
- `DB` is the database from which to download the tables (same for all tables)
- `Schema` is the database schema from which to download
- `User` is the username to use to connect to the DB

E.g.,

    %RouteLengthKM(
        WC2011BB_AL_20070920, WC2011BB_AL_TO_A_LINK_20070920,
        WC2011BB_A_20070920, RouteLength
    );

## %separate(String, Separator = %str(, ))

Given a space-separated list of words, return macro text- with those words separated by `Separator` instead of a space.

    %put %separate(a b c);

prints to log:

    a, b, c

## %simpleclean(Var)

Does rudimentary string cleaning on the specified variable of a dataset--upcase, remove accents, left-justify. Note that ligature characters don't get translated.

    data ds;
    orig = "ÄÆÉçÄÆßÑŒ";
    cleaned = orig;
    %SimpleClean(cleaned);
    run;

gives

    Obs      orig        cleaned

    1     ÄÆÉçÄÆßÑŒ    AÆECAÆßNŒ


## %simpledl(Args)

A macro to simplify downloads from ORACLE databases, where no complex
joins, calculations, or groupings are required. It can select which variables
to download, which variables to sort, and the source/destination tables.

Its sole argument, ARGS, is a formatted string detailing these simple
requirements. Its expected format is:

    destination_name_1!source_name_1|download_variables_1|sort_variables_1#
    ...
    destination_name_n!source_name_n|download_variables_n|sort_variables_n#

The hashes (#) separate the argument into a list of tables and specifications
for downloading them. The bars (|) separate the parameters of each table
specification.

The first parameter of the table specification is the source table from which
to copy, and the destination table to which to write. If there is an exclamation
mark (!) in the first component of the table specification, then the text
before it defines the table to which to write, and the part after defines the
source table. Otherwise, the whole first component is used as the source, and
the destination will be the member name of the component, written to WORK. Thus
errors are possible if the source table is from WORK.

Each table specification must have two or three components (and thus one or two
bars separating them).

If the specification has two components, then the second component is assumed
to be a space-separated list of variables to be used as the list of variables
to download from the source table, as well as the ascending sort order.

If the specification has three components, the second is assumed to be a
space-separated list of variables to download, and the third is assumed to
be a space-separated list of the ascending order sort variables.

A sample call ;

    %SimpleDL(
        CB!WH.WC2006CB_20060630|CB_UID PRCODE CDCODE CT_PCT_CODE DACODE|CB_UID#
        DA!WH.WC2006DA_20060630|DA_UID PRCODE CDCODE DACODE CSDCODE#
        WH.WC2006CSD_20060630|CSD_UID#
        WH.WC2006PR_20060630|PRCODE|PRCODE|this is a fourth component#
    );

The first specification creates table WORK.CB from WH.WC2006CB_20060630. It
downloads CB_UID through DACODE, sorting by CB_UID.

The second specification create WORK.DA from WH.WC2006DA_20060630, extracting
DA_UID through CSDCODE, and sorting by those same variables.

The third specification creates WORK.WC2006CSD_20060630 from the WH library of
the same member name, copying and ordering by CSD_UID.

The fourth specification results in an error, because there are too many
components to the table specification.

## %stopit(Message = )

Debugging macro to stop execution of interactive SAS code at the point of execution. Running:

    %stopit(Message = stop now);

results in this logging:

    ERROR: stop now

    ERROR: Execution terminated by an ABORT CANCEL statement at line 1 column 16.

## %suffix(List, Suffix)

Given a space-separated list of words, return macro text with those words suffixed with `Suffix`.

    %put %suffix(a b c, %str(a_suffix));

prints to log:

    aa_suffix ba_suffix ca_suffix

## %timer(Init = 0, GlobalVar = __Timer_SaveTime, Message = %str())

- `Init` = 1 for initialising a global macro variable to store current time
- `GlobalVar` is a macro variable name to use to store the global variable (beware of overwriting)
- `Message` is a string to print out before the elapsed time in seconds since the last call using `GlobalVar`

E.g., this should print ~5 seconds into the log:

    %Timer(Init = 1);
    * wait five seconds, then run: ;
    %Timer(Message = %str(Testing));

## %uncheckedvars(Base, Comp)

This macro is intended for use in QA routines. It prints a list of variables
in the `Comp` dataset that are not in the `Base` dataset. No regard is given to
the datatype--so long as the names are in both datasets, no printing occurs.
Thus, the macro is meant as a supplement to PROC COMPARE.

## %unlock

Sometimes, when cancelling execution of SAS in interactive mode, datasets get locked as SAS was in the middle of doing read/write operations. This macro attempts to unlock any locked datasets by using a %sysfunc call to close the first 1000 integers, which should usually unlock the files.

## %varstatus(dataset, outdataset)

Macro that does certain column-wise statistics for the input dataset. Writes to <dataset>_pop unless an output dataset is specified.

    data ds;
    alpha = "a"; num = .; alpha2 = "c"; num2 = .; output;
    alpha = "a"; num = 4; alpha2 = "c"; num2 = .; output;
    alpha = "b"; num = 5; alpha2 = "d"; num2 = .; output;
    alpha = " "; num = 0; alpha2 = "e"; num2 = .; output;
    alpha = "c"; num = .; alpha2 = "f"; num2 = .; output;
    run;
    %varstatus(ds);

yields dataset ds_pop:

           Var                               Num     Num      Num      Num
    Obs    Name      VarStatus              Zero    Miss    Unique    Recs

    1     alpha     Partially Populated      0       1        3        5
    2     num       Partially Populated      1       2        3        5
    3     alpha2    Totally Populated        0       0        4        5
    4     num2      Unpopulated              0       5        0        5



## %varstatus2(dataset, outdataset)

Alternate implementation of %varstatus.


# Tests

To write/document.
