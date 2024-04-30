* macro that takes an input dataset and loops through all character variables ;
* outputs dataset of "weird" characters found in those variables ;

%macro FindWeirdChars(Tab, OutDS);
%local Pos Curr Vars;
proc contents data = &Tab out = &OutDS(keep = NAME TYPE where = (TYPE = 2)) noprint; run;
%let CharVars = %CountObs(&OutDS);
%if (&CharVars > 0)
  %then
    %do;
      proc sql noprint;
      select NAME into :Vars separated by " " from &OutDS order by NAME;
      quit;
      run;

      data &OutDS(where = (Char ~= "") keep = VarName Char);
      set &Tab(keep = _character_);
      length VarName $32.;
      %let Pos = 1;
      %let Curr = %scan(&Vars, &Pos);
      %do %while (&Curr ~= );
        %SimpleClean(&Curr);
        Pat = prxparse("s/[a-z\d\(\)\' \-\.\,!\/&]//io");
        &Curr = prxchange(Pat, -1, &Curr);
        do i = 1 to length(&Curr);
          Char = substr(&Curr, i, 1); VarName = "&Curr"; output;
        end;
        %let Pos = %eval(&Pos + 1);
        %let Curr = %scan(&Vars, &Pos);
      %end;
      run;
      proc sort data = &OutDS nodupkey; by Char VarName; run;
    %end;
%mend;