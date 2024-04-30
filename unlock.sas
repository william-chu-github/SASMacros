* small macro to "unpoint" to datasets in case of an error locking one open ;
%macro unlock;
%local i z;
%do i = 1 %to 1000;
%let z = %sysfunc(close(&i));
%end;
%mend;
