#!/bin/sh
#
# https://www.test.de/steuerprogression-einfach-erklaert-5813257-0/
# Einkommensteuertabelle 2023 - Grundtabelle
# https://www.sthu.org/blog/02-bruttonetto/index.html
# https://www.finanz-tools.de/einkommensteuer/berechnung-formeln/2023

MAX="${1:-120000}"
STEP="${2:-100}"	# z.b. 25 Euro Schritte

FILE_CSV='all.csv'
FILE_PNG='all.png'

YEAR=2023
BRUTTO=0
STEUER=0
NETTO=0

calc()
{
	case "$2" in
		exact) echo "$1" | bc -l ;;
		    *) echo "result = ($1); scale=2; result / 1" | bc -l ;;
	esac
}

calc_steuer2023()	# input: BRUTTO => emits variables: NETTO + STEUER + PERCENT
{
	if   [ $BRUTTO -le 10908 ]; then
		STEUER=0
		NETTO=$BRUTTO
		PERCENT=0
	elif [ $BRUTTO -le 15999 ]; then	# 10.909 ... 15.999 Euro
		Y="$( calc "($BRUTTO - 10908) / 10000" exact )"
		STEUER="$( calc "((979.18*$Y)+1400)*$Y" )"
	elif [ $BRUTTO -le 62809 ]; then	# 16.000 ... 62.809 Euro
		Y="$( calc "($BRUTTO - 15999) / 10000" exact )"
		STEUER="$( calc "((192.59*$Y)+2397)*$Y + 966.53" )"
	elif [ $BRUTTO -le 277825 ]; then	# 62.810 ... 277.825 Euro
		STEUER="$( calc "((0.42*$BRUTTO) - 9972.98)" )"
	else
		# >277.825 Euro
		STEUER="$( calc "((0.45*$BRUTTO) - 18307.73)" )"
	fi

	[ $BRUTTO -gt 10908 ] && {
		NETTO="$( calc "$BRUTTO - $STEUER" )"
		PERCENT="$( calc "100-($NETTO*100/$BRUTTO)" )"
	}
}

CSV_HEADER="Brutto Netto Steuer effektive-prozentuale-Belastung*1000"
echo "$CSV_HEADER" >"$FILE_CSV"

while [ "$BRUTTO" -lt "$MAX" ]; do {
	BRUTTO=$(( BRUTTO + STEP ))
	calc_steuer$YEAR "$BRUTTO"

	NETTO_MONTH="$( calc "$NETTO/12" )"
	echo "Jahresbrutto: $BRUTTO Netto: $NETTO Steuer: $STEUER Prozent: $PERCENT (Monatsnetto: $NETTO_MONTH)"
	echo "$BRUTTO $NETTO $STEUER $PERCENT" >>"$FILE_CSV"
} done

# needs 1 euro steps and e.g.: grep -m1 " 25.00"$ all.csv
# 10 - 20281
# 15 - 28580
# 20 - 41271
# 25 - 58449
# 30 - 83109
# 35 - 142472
# 40 - 366155

printf '%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n' \
	"set object circle at first 83150,30000 radius char 0.5 fillstyle empty border lc rgb '#aa1100' lw 2" \
	"set label 'Brutto 83150 € => 30% Steuern eff.' at 75000,32500" \
	"set object circle at first 58450,25000 radius char 0.5 fillstyle empty border lc rgb '#aa1100' lw 2" \
	"set label 'Brutto 58450 € => 25% Steuern eff.' at 48450,27500" \
	"set ytics 2500" \
	"set xtics 5000" \
	"set term png" \
	"set terminal png size 1900,1000" \
	"set output '$FILE_PNG'" \
	"set ylabel 'Ergebnis'" \
	"set xlabel 'Bruttolohn in Euro im Jahr $YEAR'" \
	"set title 'Steuerlast abhängig vom Brutto'" \
	"set grid" \
	"set key autotitle columnhead" \
	"set key autotitle columnhead" \
	"plot '$FILE_CSV'   using 1:2 with lines, \\" \
			"'' using 1:3 with lines, \\" \
			"'' using 1:(\$4*1000) with lines, \\" \
			"'' using 1:1 with lines" | gnuplot && echo "see '$FILE_CSV' and '$FILE_PNG'"
