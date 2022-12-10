* macro that loops through specified datasets and removes all
  informats, formats, and variable labels ;
* specify a space-separated list of defined libraries with LIBS to
  deformat all datasets in those libraries ;
* specify a space-separated list of TABS (no prefixed library = WORK)
  to do specific tables ;
* specify both to do both ;
* this macro DOES NOT check to see if the libraries exist/are populated ;
* it DOES check to see if the TABS specified exist ;
%macro Deformat(Libs = , Tabs = );
%local Pos TabsFinal Tab Tabs Libs;
%let Libs = %upcase(&Libs);
%let Tabs = %upcase(&Tabs);
%if (&Libs = and &Tabs = )
  %then %let Libs = WORK;
* get list of datasets in the libraries ;
%if (&Libs ~= )
  %then
    %do;
      proc sql noprint;
      select compress(LibName || "." || MemName)
        into :Libs separated by " "
        from dictionary.members
        where LibName in (
                %Separate(%Suffix(
                  %bquote(%Prefix(&Libs, %bquote("))), %bquote(")
                ))
              ) and MemType = "DATA";
      quit;
      run;
    %end;
%let Pos = 1;
%let TabsFinal = ;
* if a TABS component has no period (no library) prefix with WORK. ;
%let Tab = %scan(&Tabs, &Pos, %str( ));
%do %while (&Tab ~= );
  %if %sysfunc(exist(&Tab))
    %then
      %do;
        %if (not %index(&Tab, %str(.)))
          %then %let TabsFinal = &TabsFinal WORK.&Tab;
          %else %let TabsFinal = &TabsFinal &Tab;
      %end;
  %let Pos = %eval(&Pos + 1);
  %let Tab = %scan(&Tabs, &Pos, %str( ));
%end;
* put LIBS and TABS together ;
%let Tabs = &Libs &TabsFinal;

* deformat all variables, remove all variable labels ;
%let Pos = 1;
%let Tab = %scan(&Tabs, &Pos, %str( ));
%do %while (&Tab ~= );
  %let Lib = %scan(&Tab, 1, %str(.));
  %let Tab = %scan(&Tab, 2, %str(.));
  proc datasets library = &Lib nodetails nolist;
  modify &Tab;
  format _all_; informat _all_; attrib _all_ label = "";
  quit;
  run;
  %let Pos = %eval(&Pos + 1);
  %let Tab = %scan(&Tabs, &Pos, %str( ));
%end;
%mend;
