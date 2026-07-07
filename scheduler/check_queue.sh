#!/bin/bash
set -euo pipefail

FILE="scheduler/queue.json"
export TZ="Europe/Warsaw"

CURRENT_TIMESTAMP=$(date +%s)
CURRENT_DATE=$(date '+%Y-%m-%d')
CURRENT_TIME=$(date '+%H:%M')

echo "Aktualny czas systemowy: $(date '+%Y-%m-%d %H:%M:%S')"

# =========================================================================
# SCENARIUSZ A: Istnieje zadanie w kolejce (Reczne planowanie / Nadpisanie)
# =========================================================================
if [ -s "$FILE" ] && [ "$(jq '. | length' "$FILE")" -gt 0 ]; then
  echo "Wykryto zaplanowane zadanie w queue.json. Sprawdzam..."

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
    echo "Sekundy do zaplanowanego zadania: $DIFF s"

    # Akceptujemy uruchomienie od 15 minut przed czasem do 10 minut po czasie audycji
    if [ "$DIFF" -le 900 ] && [ "$DIFF" -ge -600 ]; then
      echo "Uruchamiam nagranie z formularza!"
      echo "START_RECORDING=true" >> "$GITHUB_ENV"
      echo "REC_DURATION=$DURATION" >> "$GITHUB_ENV"
      echo "REC_BACKUP=$BACKUP" >> "$GITHUB_ENV"
      echo "REC_MEGA=$MEGA" >> "$GITHUB_ENV"

      # Usuwamy obsluzone zadanie z kolejki
      jq 'del(.[0])' "$FILE" > tmp.json && mv tmp.json "$FILE"
      echo "NEED_REPO_COMMIT=true" >> "$GITHUB_ENV"
      exit 0
    fi
  fi
  echo "Zadanie z kolejki jest na inna godzine/dzien."
fi

# =========================================================================
# SCENARIUSZ B: Kolejka pusta lub brak dopasowania -> Dzialamy wedlug CRONA
# =========================================================================
echo "Brak dopasowania w kolejce. Sprawdzam staly harmonogram (Cron)..."

DAY_OF_WEEK=$(date +%u)
HHMM=$(date '+%H:%M')

IS_CRON_MATCH=false

# Szerokie okna czasowe zabezpieczajace przed lagami GitHuba
case "$DAY_OF_WEEK" in
  2) # 🧪 Wtorek (WPIS TESTOWY)
    if [[ "$HHMM" > "16:09" && "$HHMM" < "16:31" ]]; then
       IS_CRON_MATCH=true
    fi
    ;;
  5) # Piątek
    if [[ "$HHMM" > "15:44" && "$HHMM" < "16:31" ]] || \
       [[ "$HHMM" > "18:44" && "$HHMM" < "19:31" ]] || \
       [[ "$HHMM" > "21:44" && "$HHMM" < "22:31" ]]; then
       IS_CRON_MATCH=true
    fi
    ;;
  6|7) # Sobota, Niedziela
    if [[ "$HHMM" > "00:44" && "$HHMM" < "01:31" ]] || \
       [[ "$HHMM" > "15:44" && "$HHMM" < "16:31" ]] || \
       [[ "$HHMM" > "18:44" && "$HHMM" < "19:31" ]] || \
       [[ "$HHMM" > "21:44" && "$HHMM" < "22:31" ]]; then
       IS_CRON_MATCH=true
    fi
    ;;
  1) # Poniedziałek
    if [[ "$HHMM" > "00:44" && "$HHMM" < "01:31" ]] || \
       [[ "$HHMM" > "17:44" && "$HHMM" < "18:31" ]] || \
       [[ "$HHMM" > "20:44" && "$HHMM" < "21:31" ]] || \
       [[ "$HHMM" > "23:44" && "$HHMM" < "23:59" ]]; then
       IS_CRON_MATCH=true
    fi
    ;;
esac

if [ "$IS_CRON_MATCH" = true ]; then
  echo "Wykryto dopasowanie z harmonogramem cron! Uruchamiam standardowe nagranie."
  echo "START_RECORDING=true" >> "$GITHUB_ENV"
  echo "REC_DURATION=10800" >> "$GITHUB_ENV"
  echo "REC_BACKUP=true" >> "$GITHUB_ENV"
  echo "REC_MEGA=true" >> "$GITHUB_ENV"
  echo "NEED_REPO_COMMIT=false" >> "$GITHUB_ENV"
else
  echo "Brak dopasowania. To uruchomienie nie pokrywa sie z zadna audycja."
  echo "START_RECORDING=false" >> "$GITHUB_ENV"
  echo "NEED_REPO_COMMIT=false" >> "$GITHUB_ENV"
fi
