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

BRUTTO=${START:-0}	# enforce via ENV
NETTO=0
STEUER=0	# Lohnsteuer
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
	if   [ "$BRUTTO" -le 10908 ]; then
		STEUER=0
		NETTO=$BRUTTO
		PERCENT=0
	elif [ "$BRUTTO" -le 15999 ]; then	# 10.909 ... 15.999 Euro
		Y="$( calc "($BRUTTO - 10908) / 10000" exact )"
		STEUER="$( calc "((979.18*$Y)+1400)*$Y" )"
	elif [ "$BRUTTO" -le 62809 ]; then	# 16.000 ... 62.809 Euro
		Y="$( calc "($BRUTTO - 15999) / 10000" exact )"
		STEUER="$( calc "((192.59*$Y)+2397)*$Y + 966.53" )"
	elif [ "$BRUTTO" -le 277825 ]; then	# 62.810 ... 277.825 Euro
		STEUER="$( calc "((0.42*$BRUTTO) - 9972.98)" )"
	else
		# >277.825 Euro
		STEUER="$( calc "((0.45*$BRUTTO) - 18307.73)" )"
	fi

	if [ "$BRUTTO" -le $(( 325 * 12 )) ]; then
		# Geringverdiener: bis 325 Euro zahlt Arbeitgeber Sozialversicherung allein
		PV=0
		AV=0
		RV=0
		KV=0
	else
		# Grenzen:
		# https://www.lohn-info.de/beitragsbemessungsgrenze_2023.html
		# Pflegeversicherung/PV: 2023 = 3.4% mit Kindern (Arbeitnehmer 50% davon)
		PV="3.4/2" && BRUTTO_PV="$BRUTTO" && test "$BRUTTO" -gt 59850 && BRUTTO_PV=59850		# = 4987,50 Euro/Monat
		PV="$( calc "($BRUTTO_PV/100)*$PV" )"

		# Arbeitslosenversicherung/ALV: 2023 = 2.6% (Arbeitnehmer 50% davon)
		AV="2.6/2"  && BRUTTO_AV="$BRUTTO" && test "$BRUTTO" -gt 87600 && BRUTTO_AV=87600		# = 7300,00 Euro/Monat
		AV="$( calc "($BRUTTO_AV/100)*$AV" )"

		# Deutsche Rentenversicherung/DRV: 2023 = 18.6% (Arbeitnehmer 50% davon)
		RV="18.6/2" && BRUTTO_RV="$BRUTTO" && test "$BRUTTO" -gt 87600 && BRUTTO_RV=87600		# = 7300,00 Euro/Monat
		RV="$( calc "($BRUTTO_RV/100)*$RV" )"

		# gesetzliche Krankenversicherung/GKV: 2023 = ~15% (Arbeitnehmer 50% davon)
		# billigste war: BKK firmus und die BKK GILDEMEISTER SEIDENSTICKER mit 0.90% ZUsatzbeitrag = 15.5%
		# FIXME! zwischen 520,01...2000 Euro monatlich (Midijob?) Übergangsrechnung/Gleitzone => Arbeitgeber zahlt mehr Anteil
		KV="15.5/2" && BRUTTO_KV="$BRUTTO" && test "$BRUTTO" -gt 59850 && BRUTTO_KV=59850		# = 4987,50 Euro/Monat
		KV="$( calc "($BRUTTO_KV/100)*$KV" )"
	fi

	# gesetzliche Unfallversicherung/GUV: 2023 = 0% (100% trägt Arbeitgeber)
	UV=0

	SOZIAL="$( calc "$PV + $AV + $RV + $KV + $UV" exact )"

	[ "$BRUTTO" -gt 10908 ] && {
		NETTO="$( calc "$BRUTTO - $STEUER" )"
		PERCENT="$( calc "100-($NETTO*100/$BRUTTO)" )"
	}

	export BRUTTO NETTO STEUER SOZIAL PV AV RV KV PERCENT
}

CSV_HEADER="Brutto Lohnsteuer Netto Sozialabgaben Pflegevers. Arbeitslosenvers. Rentenvers. Krankenvers. Realnetto effektive-prozentuale-Lohnsteuerbelastung*1000"
echo "$CSV_HEADER" >"$FILE_CSV"

while [ "$BRUTTO" -le "$MAX" ]; do {
	"calc_steuer${YEAR}" "$BRUTTO"

	BRUTTO_MONTH="$( calc "$BRUTTO/12" )"
	REALNETTO="$( calc "($NETTO-$SOZIAL)/1" )"
	REALNETTO_MONTH="$( calc "($NETTO-$SOZIAL)/12" )"
	SOZIAL="$( calc "$SOZIAL / 1" )"

	HOUR_BRUTTO="$( calc "$BRUTTO/(260*8)" )"
	HOUR_REALNETTO="$( calc "$REALNETTO/(260*8)" )"

	echo "Brutto_Jahr/Monat/Stunde: $BRUTTO / $BRUTTO_MONTH / $HOUR_BRUTTO Lohnsteuer%: $PERCENT Lohnsteuer: $STEUER Netto: $NETTO Sozial: $SOZIAL PV: $PV AV: $AV RV: $RV KV: $KV Realnetto_Jahr/Monat/Stunde $REALNETTO / $REALNETTO_MONTH / $HOUR_REALNETTO"
	echo "$BRUTTO $STEUER $NETTO $SOZIAL $PV $AV $RV $KV $REALNETTO $PERCENT" >>"$FILE_CSV"

	BRUTTO=$(( BRUTTO + STEP ))
} done

# Beispiele Realnetto (Brutto minus Lohnsteuer und Sozialabgaben):
# Brutto: 24960 = Mindestlohn 2023 = 12 Euro * 8h * 260 Tage
# Brutto_Jahr/Monat/Stunde: 24960 / 2080.00 / 12.00 Lohnsteuer%: 13.09 Lohnsteuer: 3269.13 Netto: 21690.87 Sozial: 5004.48 PV: 424.32 AV: 324.48 RV: 2321.28 KV: 1934.40 Realnetto_Jahr/Monat/Stunde 16686.39 / 1390.53 / 8.02
# Brutto_Jahr/Monat/Stunde: 33333 / 2777.75 / 16.02 Lohnsteuer%: 17.10 Lohnsteuer: 5700.16 Netto: 27632.84 Sozial: 6683.24 PV: 566.66 AV: 433.32 RV: 3099.96 KV: 2583.30 Realnetto_Jahr/Monat/Stunde 20949.60 / 1745.80 / 10.07
# Brutto_Jahr/Monat/Stunde: 66666 / 5555.50 / 32.05 Lohnsteuer%: 27.04 Lohnsteuer: 18026.74 Netto: 48639.26 Sozial: 12722.40 PV: 1017.45 AV: 866.65 RV: 6199.93 KV: 4638.37 Realnetto_Jahr/Monat/Stunde 35916.86 / 2993.07 / 17.26
#
# Beispiel-A:
R0=36066;R0X=66666;R0Y=$R0;J0X=$((R0X-22500));J0Y=$((R0Y+2500));R0HUMAN="$( calc "scale=3;$R0X/1000" exact )";M="$( calc "$R0/12" )"
RP="$( calc "100-(($R0*100)/$R0X)" )";R0H="$( calc "$R0X/(260*8)" )";MM="$( calc "$R0/(260*8)" )";R0="$( calc "scale=3;$R0/1000" exact )"

# Grenzen Sozialversicherung:
GRENZE_X1=59850 && GRENZE_Y1=11850 && HGRENZE_X1="$( calc "scale=3;$GRENZE_X1/1000" exact )"	# PV/KV
GRENZE_X2=87600 && GRENZE_Y2=14792 && HGRENZE_X2="$( calc "scale=3;$GRENZE_X2/1000" exact )"	# AV/RV

# Prozentuale effektive Lohnsteuerlast: needs 1 euro steps and e.g.: grep -m1 " 25.00"$ all.csv
# 10% - 20281
# 15% - 28580
# 20% - 41271
# 25% - 58449
# 30% - 83109
# 35% - 142472
# 40% - 366155
#
P0=10;P0X=20281;P0Y=$((P0*1000));L0X=$((P0X-10000));L0Y=$((P0Y+2500));P0HUMAN="$(( P0X / 1000 )).$(( P0X % 1000 ))"
P1=15;P1X=28580;P1Y=$((P1*1000));L1X=$((P1X-10000));L1Y=$((P1Y+2500));P1HUMAN="$(( P1X / 1000 )).$(( P1X % 1000 ))"
P2=20;P2X=41271;P2Y=$((P2*1000));L2X=$((P2X-10000));L2Y=$((P2Y+2500));P2HUMAN="$(( P2X / 1000 )).$(( P2X % 1000 ))"
P3=25;P3X=58449;P3Y=$((P3*1000));L3X=$((P3X-10000));L3Y=$((P3Y+2500));P3HUMAN="$(( P3X / 1000 )).$(( P3X % 1000 ))"
P4=30;P4X=83109;P4Y=$((P4*1000));L4X=$((P4X-10000));L4Y=$((P4Y+2500));P4HUMAN="$(( P4X / 1000 )).$(( P4X % 1000 ))"

printf '%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n' \
	"set object circle at first $R0X,$R0Y radius char 0.5 fillstyle empty border lc rgb '#00ff00' lw 2" \
	"set label 'Brutto $R0HUMAN € / $R0H €/h => $RP% Abgaben => $R0 € Realnetto = $M € monatlich = $MM €/h' at $J0X,$J0Y" \
	"set object circle at first $P0X,$P0Y radius char 0.5 fillstyle empty border lc rgb '#aa1100' lw 2" \
	"set label 'Brutto $P0HUMAN € => $P0% Lohnsteuer eff.' at $L0X,$L0Y" \
	"set object circle at first $P1X,$P1Y radius char 0.5 fillstyle empty border lc rgb '#aa1100' lw 2" \
	"set label 'Brutto $P1HUMAN € => $P1% Lohnsteuer eff.' at $L1X,$L1Y" \
	"set object circle at first $P2X,$P2Y radius char 0.5 fillstyle empty border lc rgb '#aa1100' lw 2" \
	"set label 'Brutto $P2HUMAN € => $P2% Lohnsteuer eff.' at $L2X,$L2Y" \
	"set object circle at first $P3X,$P3Y radius char 0.5 fillstyle empty border lc rgb '#aa1100' lw 2" \
	"set label 'Brutto $P3HUMAN € => $P3% Lohnsteuer eff.' at $L3X,$L3Y" \
	"set object circle at first $P4X,$P4Y radius char 0.5 fillstyle empty border lc rgb '#aa1100' lw 2" \
	"set label 'Brutto $P4HUMAN € => $P4% Lohnsteuer eff.' at $L4X,$L4Y" \
	"set arrow from $GRENZE_X1,0 to $GRENZE_X1,$GRENZE_Y1 nohead lc rgb '#bdc3c7'" \
	"set object circle at first $GRENZE_X1,$GRENZE_Y1 radius char 0.5 fillstyle empty border lc rgb '#aa1100' lw 2" \
	"set label 'Obergrenze Kranken/Plegeversicherung $HGRENZE_X1 €' at $(( GRENZE_X1 - 12500 )),$(( GRENZE_Y1 / 2 ))" \
	"set arrow from $GRENZE_X2,0 to $GRENZE_X2,$GRENZE_Y2 nohead lc rgb '#bdc3c7'" \
	"set object circle at first $GRENZE_X2,$GRENZE_Y2 radius char 0.5 fillstyle empty border lc rgb '#aa1100' lw 2" \
	"set label 'Obergrenze Renten-/Arbeitslosenversicherung $HGRENZE_X2 €' at $(( GRENZE_X2 - 12500 )),$(( GRENZE_Y2 / 2 ))" \
	"set ytics 2500" \
	"set xtics 5000" \
	"set term png" \
	"set terminal png size 1900,1000" \
	"set output '$FILE_PNG'" \
	"set ylabel 'Ergebnis'" \
	"set xlabel 'Jahresbruttolohn in Euro im Jahr $YEAR'" \
	"set title 'Jährliche Abgaben- und Steuerlast für Arbeitnehmer abhängig vom Brutto (verheiratet, 2 Kinder, alte Bundesländer)'" \
	"set grid" \
	"set key autotitle columnhead" \
	"plot '$FILE_CSV'   using 1:3 with lines, \\" \
			"'' using 1:2 with lines, \\" \
			"'' using 1:4 with lines, \\" \
			"'' using 1:(\$10*1000) with lines, \\" \
			"'' using 1:(\$1-\$2-\$4) title 'Realnetto (Brutto abzüglich Lohnsteuer und Sozialabgaben)' with lines, \\" \
			"'' using 1:1 with lines" | gnuplot && echo "see '$FILE_CSV' and '$FILE_PNG'"
