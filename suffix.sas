/*
Given a space-separated list, append the given suffix to each component.
Works as a function--use only in macro code.
*/
%macro Suffix(List, Suffix);
%local Result;
%let Result =
  %bquote(%sysfunc(
    tranwrd(%bquote(%trim(%bquote(%left(%bquote(%cmpres(%bquote(&List))))))),
    %str( ),
    &Suffix%str( ))
  ))%bquote(&Suffix);
%do; %unquote(&Result) %end;
%mend;

