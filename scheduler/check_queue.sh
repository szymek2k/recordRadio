# =========================================================================
# SCENARIUSZ B: Kolejka pusta lub brak dopasowania -> Działamy według CRONA
# =========================================================================
echo "🤖 Brak dopasowania w kolejce. Sprawdzam stały harmonogram (Cron)..."

DAY_OF_WEEK=$(date +%u)
HHMM=$(date '+%H:%M')

IS_CRON_MATCH=false

# Rozszerzamy okno: akceptujemy uruchomienie od XX:45 do połowy kolejnej godziny (XX:30)
# zabezpieczając skrypt przed dużymi opóźnieniami infrastruktury GitHub Actions.

case "$DAY_OF_WEEK" in
  5|6|7) # Piątek, Sobota, Niedziela
    if [[ "$HHMM" > "13:44" && "$HHMM" < "14:31" ]] || \
       [[ "$HHMM" > "16:44" && "$HHMM" < "17:31" ]] || \
       [[ "$HHMM" > "19:44" && "$HHMM" < "20:31" ]] || \
       [[ "$HHMM" > "22:44" && "$HHMM" < "23:31" ]]; then
       IS_CRON_MATCH=true
    fi
    ;;
  1) # Poniedziałek
    if [[ "$HHMM" > "14:44" && "$HHMM" < "15:31" ]] || \
       [[ "$HHMM" > "17:44" && "$HHMM" < "18:31" ]] || \
       [[ "$HHMM" > "20:44" && "$HHMM" < "21:31" ]]; then
       IS_CRON_MATCH=true
    fi
    ;;
esac