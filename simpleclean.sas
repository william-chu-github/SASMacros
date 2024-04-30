* takes a dataset character variable, upcases it, removes some accents, and
  lefts ;
%macro SimpleClean(Var);
&Var = left(upcase(basechar(&Var)));
%mend;

/*
* can try to use basechar() instead, but it doesn't clean ligatures... but neither does original ;
data z;
x = "ÄÆÉçÄÆßÑŒ";
y = basechar(x);
run;


&Var = left(translate(
  upcase(&Var),
  "AAAAAACEEEEIIIINOOOOOUUUUY",
  "ÀÁÂÃÄÅÇÈÉÊËÌÍÎÏÑÒÓÔÕÖÙÚÛÜİ"
));

*/