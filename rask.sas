%macro RASK(St, StLen, Type, Dir, Pr, DropArt = 0);
do;
  %create_search_key_nov042005(&St, &StLen, &Type, &Dir, &Pr);
  drop Tag %if (&DropArt) %then %do; &St._KEY_NO_ART %end;;
end;
%mend;