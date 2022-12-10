* timer macro ;
*
- INIT = 0 for initialising a global macro variable to store current time
- GLOBALVAR is a macro variable name to use to store the global variable (beware of overwriting)
- MESSAGE is a string to print out before the elapsed time in seconds since the last call using GLOBALVAR
;

/* e.g., this should print ~5 seconds into the log:
%Timer(Init = 1);
* wait five seconds, then run: ;
%Timer(Message = %str(Testing));
*/
%macro Timer(Init = 0, GlobalVar = __Timer_SaveTime, Message = %str());
%local Curr;
%if (&Init)
  %then
    %do;
      %global &GlobalVar;
      %let &GlobalVar = %sysfunc(datetime());
    %end;
  %else
    %do;
      %let Curr = %sysfunc(datetime());
      %put %trim(&Message) %sysevalf(&Curr - &&&GlobalVar);
      %let &GlobalVar = &Curr;
    %end;
%mend;
