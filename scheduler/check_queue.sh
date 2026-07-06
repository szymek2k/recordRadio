#!/bin/bash
set -euo pipefail

FILE="scheduler/queue.json"
export TZ="Europe/Warsaw"

CURRENT_TIMESTAMP=$(date +%s)
CURRENT_DATE=$(date '+%Y-%m-%d')
CURRENT_TIME=$(date '+%H:%M')

echo "🕒 Aktualny czas systemowy: $(date '+%Y-%m-%d %H:%M:%S')"

# =========================================================================
# SCENARIUSZ A: Istnieje zadanie w kolejce (Ręczne planowanie / Nadpisanie)
# =========================================================================
if [ -s "$FILE" ] && [ "$(jq '. | length' "$FILE")" -gt 0 ]; then
  echo "📅 Wykryto zaplanowane zadanie w queue.json. Sprawdzam..."

  JOB=$(jq '.[0]' "$FILE")
  JOB_DATE=$(echo "$JOB" | jq -r '.date')
  JOB_TIME=$(echo "$JOB" | jq -r '.time')
  DURATION=$(echo "$JOB" | jq -r '.duration')
  BACKUP=$(echo "$JOB" | jq -r '.backup')
  MEGA=$(echo "$JOB" | jq -r '.mega')

  TARGET_DATETIME="$JOB_DATE $JOB_TIME"
  TARGET_TIMESTAMP=$(date -d "$TARGET_DATETIME" +%s 2>/dev/null || echo "")

  if [ -n "$TARGET_TIMESTAMP" ]; then
    DIFF=$((TARGET_TIMESTAMP - CURRENT_TIMESTAMP))
    echo "⏳ Sekundy do zaplanowanego zadania: $DIFF s"

    if [ "$DIFF" -le 900 ] && [ "$DIFF" -ge -1800 ]; then
      echo "🚀 [Kolejka] Uruchamiam nagranie z formularza!"
      echo "START_RECORDING=true" >> "$GITHUB_ENV"
      echo "REC_DURATION=$DURATION" >> "$GITHUB_ENV"
      echo "REC_BACKUP=$BACKUP" >> "$GITHUB_ENV"
      echo "REC_MEGA=$MEGA" >> "$GITHUB_ENV"

      # Usuwamy obsłużone zadanie z kolejki
      jq 'del(.[0])' "$FILE" > tmp.json && mv tmp.json "$FILE"
      echo "NEED_REPO_COMMIT=true" >> "$GITHUB_ENV"
      exit 0
    fi
  fi
  echo "😴 Zadanie z kolejki jest na późniejszą godzinę/dzień."
fi

# =========================================================================
# SCENARIUSZ B: Kolejka pusta lub brak dopasowania -> Działamy według CRONA
# =========================================================================
echo "🤖 Brak dopasowania w kolejce. Sprawdzam stały harmonogram (Cron)..."

# Pobieramy dzień tygodnia (1 = Poniedziałek, 5 = Piątek, 6 = Sobota, 7 = Niedziela)
DAY_OF_WEEK=$(date +%u)
# Godzina i minuta w formacie HH:MM (np. 13:50)
HHMM=$(date '+%H:%M')

# Definiujemy dopuszczalne okna czasowe (ponieważ cron odpala się o XX:50)
# Akceptujemy uruchomienie w przedziale XX:45 do XX:55
IS_CRON_MATCH=false

case "$DAY_OF_WEEK" in
  5|6|7) # Piątek, Sobota, Niedziela (odpowiednik cronów 5,6,0)
    if [[ "$HHMM" > "13:44" && "$HHMM" < "13:56" ]] || \
       [[ "$HHMM" > "16:44" && "$HHMM" < "16:56" ]] || \
       [[ "$HHMM" > "19:44" && "$HHMM" < "19:56" ]] || \
       [[ "$HHMM" > "22:44" && "$HHMM" < "22:56" ]]; then
       IS_CRON_MATCH=true
    fi
    ;;
  1) # Poniedziałek
    if [[ "$HHMM" > "14:44" && "$HHMM" < "14:56" ]] || \
       [[ "$HHMM" > "17:44" && "$HHMM" < "17:56" ]] || \
       [[ "$HHMM" > "20:44" && "$HHMM" < "20:56" ]]; then
       IS_CRON_MATCH=true
    fi
    ;;
esac

if [ "$IS_CRON_MATCH" = true ]; then
  echo "🎯 Wykryto dopasowanie z harmonogramem cron! Uruchamiam standardowe nagranie."
  echo "START_RECORDING=true" >> "$GITHUB_ENV"
  echo "REC_DURATION=10800" >> "$GITHUB_ENV" # Domyślnie 3 godziny
  echo "REC_BACKUP=true" >> "$GITHUB_ENV"    # Domyślnie włączony backup
  echo "REC_MEGA=true" >> "$GITHUB_ENV"      # Domyślnie wysyłaj na MEGA
  echo "NEED_REPO_COMMIT=false" >> "$GITHUB_ENV"
else
  echo "🛑 Brak dopasowania. To uruchomienie nie pokrywa się z żadną audycją."
  echo "START_RECORDING=false" >> "$GITHUB_ENV"
  echo "NEED_REPO_COMMIT=false" >> "$GITHUB_ENV"
fi