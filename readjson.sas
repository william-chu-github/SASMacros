/*
Reads a JSON file. Used mainly to read the datatable extracted from a file-based spatial format
exported from geopandas. Assumption is the file is encoded in the same encoding as SAS (generally,
Windows Latin 1).
* File is the path + name + extension of the JSON file. A map file will be created (same file, with
  additional ".map" appended) to enable SAS to read the data.
* OutDS is the dataset to which to write the parsed data.
* LibName is a library name to give to the JSON file. Deassigned after reading the file.

Example call:
%ReadJSON(c:\docs\download\work\test.json, testreadjson, z);
*/
%macro ReadJSON(File, OutDS, LibName);
libname &LibName json "&File" map = "&File..map" automap = create;
data &OutDS;
set &LibName..data;
run;
libname &LibName clear;
%mend;

