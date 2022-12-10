* English/French variable name concordance ;
* datalines not allowed in macros, so have to read from external file--which is hardcoded ;
* input dataset will be overwritten ;
%macro EnglishFrenchRenames(DS);
%local RenameDS TempDS NewDSNames Renames;
%let NewDSNames = %GetNewDSNames(NumNames = 2);
%let RenameDS = %scan(&NewDSNames, 1);
%let TempDS = %scan(&NewDSNames, 2);
data &RenameDS;
infile "C:\Docs\SAS_Code\Macros\renames.txt";
length Eng Fre $20.;
input Eng $ Fre $;
Eng = upcase(Eng); Fre = upcase(Fre);
run;

%let renames = ;
proc contents data = &DS noprint out = &TempDS; run;
proc sql noprint;
create table &TempDS as
  select trim(Fre) || " = " || trim(Eng) as Command
    from &TempDS, &RenameDS
    where upcase(&TempDS..name) = upcase(&RenameDS..Fre);
select Command into :Renames separated by " " from &TempDS;
quit;
run;
proc delete data = &RenameDS &TempDS; run;
data &DS;
set &DS(rename = (&Renames));
run;
%mend;
