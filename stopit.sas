/*
Debugging macro to stop execution of interactive SAS code at the point of execution
*/

%macro StopIt(Message = );
%if (&Message ~= )
  %then %put ERROR: &Message;
data _null_;
abort cancel;
run;
%mend;

