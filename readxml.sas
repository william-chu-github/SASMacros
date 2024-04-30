/*
Reads an XML file. Used mainly to read the datatable extracted from a file-based spatial format
exported from geopandas. Assumption is the file is encoded in the same encoding as SAS (generally,
Windows Latin 1).
* File is the path + name + extension of the XML file. A map file is also expected (same file, with
  additional ".map" appended) to enable SAS to read the data.
* OutDS is the dataset to which to write the parsed data.
* LibName is a library name and file reference to give to the XML file. Deassigned after reading the file.

Example call:
%ReadXML(c:\docs\download\work\test.xml, testreadxml, z);
*/
%macro ReadXML(File, OutDS, LibName);
filename &LibName "&File";
libname &LibName xmlv2 xmlmap = "&File..map" access = readonly;
data &OutDS;
set &LibName..table;
run;
libname &LibName clear;
filename &LibName clear;
%mend;

