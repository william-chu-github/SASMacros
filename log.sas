%macro Log(Message);
%let DT = %sysfunc(putn(%sysfunc(datetime()), datetime.));
%put &DT &Message;
%mend;
