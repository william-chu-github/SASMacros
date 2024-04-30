/*
Given a space-separated list, prepend the given prefix to each component.
Works as a function -- use only in macro code.
*/
%macro Prefix(List, Prefix);
%local Result;
%let Result =
  %bquote(&Prefix)%bquote(%sysfunc(
    tranwrd(%bquote(%trim(%bquote(%left(%bquote(%cmpres(%bquote(&List))))))),
    %str( ),
    %str( )%bquote(&Prefix))
  ));
%do; %unquote(&Result) %end;
%mend;
