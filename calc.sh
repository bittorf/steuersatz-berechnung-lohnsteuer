#!/bin/sh
#
# https://www.test.de/steuerprogression-einfach-erklaert-5813257-0/
# Einkommensteuertabelle 2023 - Grundtabelle
# https://www.sthu.org/blog/02-bruttonetto/index.html
# https://www.finanz-tools.de/einkommensteuer/berechnung-formeln/2023

YEAR="${1:-2023}"
MAX="${2:-120000}"
STEP="${3:-100}"	# z.b. 25 Euro Schritte

FILE_CSV='all.csv'
FILE_PNG='all.png'

YEAR=2023
BRUTTO=0
STEUER=0	# Lohnsteuer
NETTO=0
SOZIAL=0

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

	# Pflegeversicherung/PV: 2023 = 3.4% mit Kindern (Arbeitnehmer 50% davon)
	# Arbeitslosenversicherung/ALV: 2023 = 2.6% (Arbeitnehmer 50% davon)
	# Deutsche Rentenversicherung/DRV: 2023 = 18.6% (Arbeitnehmer 50% davon)
	# gesetzliche Krankenversicherung/GKV: 2023 = ~15% (Arbeitnehmer 50% davon)
	S1="3.4/2"
	S2="2.6/2"
	S3="18.6/2"
	S4="15/2"
	SOZIAL="$( calc "($BRUTTO/100*$S1) + ($BRUTTO/100*$S2) + ($BRUTTO/100*$S3) + ($BRUTTO/100*$S4)" exact )"

	[ $BRUTTO -gt 10908 ] && {
		NETTO="$( calc "$BRUTTO - $STEUER" )"
		PERCENT="$( calc "100-($NETTO*100/$BRUTTO)" )"
	}
}

CSV_HEADER="Brutto Netto Lohnsteuer effektive-prozentuale-Belastung*1000"
echo "$CSV_HEADER" >"$FILE_CSV"

while [ "$BRUTTO" -lt "$MAX" ]; do {
	BRUTTO=$(( BRUTTO + STEP ))
	calc_steuer$YEAR "$BRUTTO"

	NETTO_MONTH="$( calc "$NETTO/12" )"
	REALNETTO_MONTH="$( calc "($NETTO-$SOZIAL)/12" )"
	SOZIAL="$( calc "$SOZIAL / 1" )"
	echo "Jahresbrutto: $BRUTTO Netto: $NETTO Steuer: $STEUER Sozial: $SOZIAL Prozent: $PERCENT (Monatsnetto: $NETTO_MONTH / $REALNETTO_MONTH)"
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

P0=15;P0X=28580;P0Y=$((P0*1000));L0X=$((P0X-10000));L0Y=$((P0Y+2500))
P1=20;P1X=41271;P1Y=$((P1*1000));L1X=$((P1X-10000));L1Y=$((P1Y+2500))
P2=25;P2X=58449;P2Y=$((P2*1000));L2X=$((P2X-10000));L2Y=$((P2Y+2500))
P3=30;P3X=83109;P3Y=$((P3*1000));L3X=$((P3X-10000));L3Y=$((P3Y+2500))

printf '%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n' \
	"set object circle at first $P0X,$P0Y radius char 0.5 fillstyle empty border lc rgb '#aa1100' lw 2" \
	"set label 'Brutto $P0X € => $P0% Steuern eff.' at $L0X,$L0Y" \
	"set object circle at first $P1X,$P1Y radius char 0.5 fillstyle empty border lc rgb '#aa1100' lw 2" \
	"set label 'Brutto $P1X € => $P1% Steuern eff.' at $L1X,$L1Y" \
	"set object circle at first $P2X,$P2Y radius char 0.5 fillstyle empty border lc rgb '#aa1100' lw 2" \
	"set label 'Brutto $P2X € => $P2% Steuern eff.' at $L2X,$L2Y" \
	"set object circle at first $P3X,$P3Y radius char 0.5 fillstyle empty border lc rgb '#aa1100' lw 2" \
	"set label 'Brutto $P3X € => $P3% Steuern eff.' at $L3X,$L3Y" \
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
