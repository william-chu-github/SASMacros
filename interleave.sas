/*
Generate a component-wise list of x_n = y_n given two input lists x and y.
Assumes the two input lists are space-separated, and of the same length
(word-wise). e.g., %Interleave(a b c, 1 2 3) will return a macro string of:
  a = 1 b = 2 c = 3
The major application for this macro would be generating RENAME = strings
in data steps. Works as a function--use only in macro code.

The additional parameters INTERLEAVER and SEPARATOR can be left alone to
generate rename strings, but can be filled in to generate more complicated
interleavings. INTERLEAVER is the sequence of characters that will be inserted
between the respective components of the LIST1 and LIST2. SEPARATOR is the
sequence of characters that will be inserted after each interleaved pair except
the last.

e.g.,
  %Interleave(
    BB.CB_UID CB.PRCODE||CB.CDCODE||CB.CSDCODE,
    CB.CB_UID CSD.CSD_UID,
    Interleaver = %str( = ), Separator = %str( and )
  );
would yield
  BB.CB_UID = CB.CB_UID and CB.PRCODE||CB.CDCODE||CB.CSDCODE = CSD.CSD_UID
Note that the first list argument with the concatenations above cannot have
spaces between the pipes, as they would be interpreted as different components
of the list.
*/
%macro Interleave(
  List1, List2, Interleaver = %str( = ), Separator = %str( )
);
%local OutString Pos CurrWord OutString;
%let Pos = 1;
%let CurrWord = %scan(&List1, &Pos, %str( ));
%do %while (&CurrWord ~= );
  %if (&OutString ~= )
    %then %let OutString = &OutString.&Separator;
  %let OutString =
    &OutString.&CurrWord.&Interleaver.%scan(&List2, &Pos, %str( ));
  %let Pos = %eval(&Pos + 1);
  %let CurrWord = %scan(&List1, &Pos, %str( ));
%end;
%do; &OutString %end;
%mend;
