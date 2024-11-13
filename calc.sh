#!/bin/sh
# shellcheck shell=dash
#
# https://www.test.de/steuerprogression-einfach-erklaert-5813257-0/
# Einkommensteuertabelle 2023 - Grundtabelle
# https://www.sthu.org/blog/02-bruttonetto/index.html
# https://www.finanz-tools.de/einkommensteuer/berechnung-formeln/2023
# FIXME: Der Begriff "Reallohn" meint etwas anderes, als hier verwendet: https://www.destatis.de/DE/Themen/Arbeit/Verdienste/Realloehne-Nettoverdienste/_inhalt.html
# FIXME: der SOLI muss noch auf die Abgaben drauf (ist nicht in der Standardformel enthalten)
#
# Median:
# TODO: median-einkommen => z.b. blass in den hintergrund plotten
# TODO: https://www.destatis.de/DE/Themen/Arbeit/Verdienste/Verdienste-Branche-Berufe/_inhalt.html
# 2023 = 43842 https://www.handelsblatt.com/politik/deutschland/gehaltsreport-2023-bestbezahlte-berufe-in-deutschland/24504394.html
# 2023 = 43750 https://www.gehalt.de/news/der-neue-stepstone-gehaltsreport-wie-fair-sind-die-gehaelter-2023#datenbasis-und-methode-des-gehaltsreport
# 2023 = 44407 https://www.capital.de/karriere/medianeinkommen--so-viel-verdienen-die-deutschen-im-mittel-31108506.html
# 2019 = 24730 https://www.wsi.de/de/verteilungsbericht-2022-30037-medianeinkommen-30065.htm


YEAR="${1:-2023}"
MAX="${2:-120000}"
STEP="${3:-100}"	# z.b. 25 Euro Schritte

case "$YEAR" in
	2023) tax_function="calc_steuer${YEAR}" ;;
	*) echo "[ERROR] year '${YEAR:-unset}' not implemented"; exit 1 ;;
esac

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
	BRUTTO="$1"

	if   [ "$BRUTTO" -le 10908 ]; then	# Berechnungsformel: https://www.lohn-info.de/lohnsteuerzahlen.html
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
		# FIXME! zwischen 520,01...2000 Euro monatlich ("Midijob") Übergangsrechnung/Gleitzone => Arbeitgeber zahlt mehr Anteil
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

	export MAX_KVPV=59850		# Obergrenze Kranken-/Pflegeversicherung
	export MAX_RVAV=87600		# Obergrenze Renten-/Arbeitslosenversicherung

	export LS10=20281	# Prozentuale effektive Lohnsteuerlast: needs 1 euro steps and e.g.: grep -m1 " 25.00"$ all.csv
	export LS15=28580
	export LS20=41271
	export LS25=58449
	export LS30=83109
	export LS35=142472
	export LS40=366155
}

calc_misc()
{
	BRUTTO_MONTH="$( calc "$BRUTTO/12" )"
	REALNETTO="$( calc "($NETTO-$SOZIAL)/1" )"
	REALNETTO_MONTH="$( calc "($NETTO-$SOZIAL)/12" )"
	SOZIAL="$( calc "$SOZIAL / 1" )"
	ABGABEN_PERCENT="$( calc "100-(($REALNETTO*100)/$BRUTTO)" )"

	HOUR_BRUTTO="$(    calc "$BRUTTO   /(260*8)" )"
	HOUR_REALNETTO="$( calc "$REALNETTO/(260*8)" )"
}

calc_tax()
{
	export BRUTTO="$1"
	"$tax_function" "$BRUTTO"
	calc_misc
}

CSV_HEADER="Brutto Lohnsteuer Netto Sozialabgaben Pflegevers. Arbeitslosenvers. Rentenvers. Krankenvers. Realnetto effektive-prozentuale-Lohnsteuerbelastung*1000"
echo "$CSV_HEADER" >"$FILE_CSV"

while [ "$BRUTTO" -le "$MAX" ]; do {
	calc_tax "$BRUTTO"

	echo "Brutto_Jahr/Monat/Stunde: $BRUTTO / $BRUTTO_MONTH / $HOUR_BRUTTO Lohnsteuer%: $PERCENT Lohnsteuer: $STEUER Netto: $NETTO Sozial: $SOZIAL PV: $PV AV: $AV RV: $RV KV: $KV Realnetto_Jahr/Monat/Stunde: $REALNETTO / $REALNETTO_MONTH / $HOUR_REALNETTO"
	echo "$BRUTTO $STEUER $NETTO $SOZIAL $PV $AV $RV $KV $REALNETTO $PERCENT" >>"$FILE_CSV"

	BRUTTO=$(( BRUTTO + STEP ))
} done

dot_with_label()
{
	local dot_color="$1"
	local dot_x="${2%.*}"			# cut off before dot
	local dot_y="${3%.*}"			# cut off before dot
	local line_orientation="$4"		# upper,lower,none
	local label="$5"			# TODO: convert all numbers to humanreadable (e.g. 23.500)

	local linestart_x linestart_y labelstart_x labelstart_y

	case "$dot_color" in
		red)    dot_color='#00ff00' ;;
		orange) dot_color='#ffa500' ;;
		green)  dot_color='#aa1100' ;;
	esac

	case "$line_orientation" in
		upper)
			linestart_x=$((  dot_x - 15000 ))
			linestart_y=$((  dot_y + 30000 ))
			labelstart_x=$(( dot_x - 37500 )) && test "$labelstart_x" -ge 500 || labelstart_x=500
			labelstart_y=$(( dot_y + 32500 ))
		;;
		lower)
			linestart_x=$(( dot_x - 5000 ))
			linestart_y=$(( (dot_y / 2) + 1000 ))
			labelstart_x=$(( dot_x - 12500 )) && test "$labelstart_x" -ge 500 || labelstart_x=500
			labelstart_y=$(( dot_y / 2 ))
		;;
		none_below|none_above)
			linestart_x=$dot_x
			linestart_y=$dot_y
			labelstart_x=$(( dot_x -  8000 ))

			case "$line_orientation" in
				none_below) labelstart_y=$(( dot_y -  2500 )) ;;
				none_above) labelstart_y=$(( dot_y +  2500 )) ;;
			esac
		;;
	esac

	printf '%s\n%s\n%s\n' \
		"set object circle at first $dot_x,$dot_y radius char 0.5 fillstyle empty border linecolor rgb '$dot_color' linewidth 2" \
		"set arrow from $linestart_x,$linestart_y to $dot_x,$dot_y nohead lc rgb '#aabbcc'" \
		"set label '$label' at $labelstart_x,$labelstart_y"
}

example_realnetto()
{
	local brutto="$1"
	local text="$2"

	calc_tax "$brutto"
	text="$text: Brutto $BRUTTO € / $HOUR_BRUTTO €/h => $ABGABEN_PERCENT% Abgaben => ${REALNETTO%.*} € Realnetto = ${REALNETTO_MONTH%.*} € monatlich = $HOUR_REALNETTO €/h"
	dot_with_label 'red' "$BRUTTO" "$REALNETTO" upper "$text"
}

gnuplot_out()
{
	cat <<EOF
set term png
set terminal png size 1900,1000
set output '$FILE_PNG'

set grid
set ytics 2500
set xtics 5000

set key autotitle columnhead
set ylabel 'Ergebnis'
set xlabel 'Jahresbruttolohn in Euro im Jahr $YEAR'
set title 'BRD: Jährliche Abgaben- und Steuerlast für Arbeitnehmer abhängig vom Brutto (verheiratet, 2 Kinder, alte Bundesländer, 40-Stunden-Woche)'

#P0=10;P0X=20281;P0Y=$((P0*1000));L0X=$((P0X-10000));L0Y=$((P0Y+2500));P0HUMAN="$(( P0X / 1000 )).$(( P0X % 1000 ))"
# Lohnsteuer-Markierungen:
$( BRUTTO="$LS10" && P=10 && calc_tax "$BRUTTO" && dot_with_label 'green' "$BRUTTO" "$(( P * 1000 ))" none_below "Brutto $BRUTTO € => $P% Lohnsteuer eff." )
$( BRUTTO="$LS15" && P=15 && calc_tax "$BRUTTO" && dot_with_label 'green' "$BRUTTO" "$(( P * 1000 ))" none_below "Brutto $BRUTTO € => $P% Lohnsteuer eff." )
$( BRUTTO="$LS20" && P=20 && calc_tax "$BRUTTO" && dot_with_label 'green' "$BRUTTO" "$(( P * 1000 ))" none_below "Brutto $BRUTTO € => $P% Lohnsteuer eff." )
$( BRUTTO="$LS25" && P=25 && calc_tax "$BRUTTO" && dot_with_label 'green' "$BRUTTO" "$(( P * 1000 ))" none_above "Brutto $BRUTTO € => $P% Lohnsteuer eff." )
$( BRUTTO="$LS30" && P=30 && calc_tax "$BRUTTO" && dot_with_label 'green' "$BRUTTO" "$(( P * 1000 ))" none_above "Brutto $BRUTTO € => $P% Lohnsteuer eff." )
$( BRUTTO="$LS35" && P=35 && calc_tax "$BRUTTO" && dot_with_label 'green' "$BRUTTO" "$(( P * 1000 ))" none_above "Brutto $BRUTTO € => $P% Lohnsteuer eff." )
$( BRUTTO="$LS40" && P=40 && calc_tax "$BRUTTO" && dot_with_label 'green' "$BRUTTO" "$(( P * 1000 ))" none_above "Brutto $BRUTTO € => $P% Lohnsteuer eff." )

# Mindestlohn:
$( example_realnetto 24960 'Mindestlohn' )

# Median:
$( example_realnetto 43750 'Median' )

# Beispiel:
$( example_realnetto 66842 'Beispiel' )
$( example_realnetto 96000 'Milchbauer' )

# KV/PV-max-Grenze:
$( calc_tax "$MAX_KVPV" && dot_with_label 'orange' "$BRUTTO" "$SOZIAL" lower "Obergrenze Kranken-/Plegeversicherung $BRUTTO €" )

# RV/AV-max-Grenze:
$( calc_tax "$MAX_RVAV" && dot_with_label 'orange' "$BRUTTO" "$SOZIAL" lower "Obergrenze Renten-/Arbeitslosenversicherung $BRUTTO €" )

plot '$FILE_CSV'   using 1:3 with lines, \\
		'' using 1:2 with lines, \\
		'' using 1:4 with lines, \\
		'' using 1:(\$10*1000) with lines, \\
		'' using 1:(\$1-\$2-\$4) title 'Realnetto (Brutto abzüglich Lohnsteuer und Sozialabgaben)' with lines, \\
		'' using 1:1 with lines
EOF
}

gnuplot_out | gnuplot && echo "see '$FILE_CSV' and '$FILE_PNG'"
