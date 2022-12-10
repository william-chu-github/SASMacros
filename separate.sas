%macro Separate(String, Separator = %str(, ));
%local Separated;
%let Separated = %sysfunc(
  tranwrd(%trim(%cmpres(&String)), %str( ), &Separator)
);
%do; &Separated %end;
%mend Separate;
