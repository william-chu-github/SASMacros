/*
Utility macro that applies another macro PROC to each component of a
comma-separated list of arguments ARGS. ARGS will need to be quoted.

Example usage:

%let Args = %quote(
  12 arg2 = 24, 5 arg2 =6, 9 arg2=90, 45 arg2=72, 0 arg2=   3
);
%macro Z(arg1, arg2=);
%put &arg1, &arg2, %sysevalf(&arg1 / 2), %sysevalf(&arg2 / 2);
%mend;
%Apply(Z, &Args);

*/
%macro Apply(Proc, Args);
%local Pos Curr Code;
%let Pos = 1;
%let Curr = %scan(&Args, &Pos, %quote(,));
%do %while (%quote(&Curr) ~= );
  * convert spaces-equals-spaces to single equals ;
  %let Code = %qsysfunc(prxparse(s/\s*=\s*/=/io));
  %let Curr = %qsysfunc(prxchange(&Code, -1, &Curr));
  * convert internal spaces to commas ;
  %let Code = %qsysfunc(prxparse(s/\s+/%quote(,)/io));
  %let Curr = %sysfunc(prxchange(&Code, -1, %left(%trim(&Curr))));
  * call for current list of arguments ;
  %&Proc(&Curr);
  %let Pos = %eval(&Pos + 1);
  %let Curr = %scan(&Args, &Pos, %quote(,));
%end;
%mend;
