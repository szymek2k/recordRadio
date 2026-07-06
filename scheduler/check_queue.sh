#!/bin/bash
set -euo pipefail

FILE="scheduler/queue.json"
export TZ="Europe/Warsaw"

# 1. Sprawdź, czy kolejka istnieje i ma elementy
if [ ! -s "$FILE" ] || [ "$(jq '. | length' "$FILE")" -eq 0 ]; then
  echo "ℹ️ Kolejka jest pusta. Brak zadań."
  echo "START_RECORDING=false" >> "$GITHUB_ENV"
  exit 0
fi

# 2. Wyciągnij pierwsze zadanie
JOB=$(jq '.[0]' "$FILE")
JOB_DATE=$(echo "$JOB" | jq -r '.date')
JOB_TIME=$(echo "$JOB" | jq -r '.time')
DURATION=$(echo "$JOB" | jq -r '.duration')
BACKUP=$(echo "$JOB" | jq -r '.backup')
MEGA=$(echo "$JOB" | jq -r '.mega')

# 3. Oblicz różnicę czasu w strefie polskiej
TARGET_DATETIME="$JOB_DATE $JOB_TIME"
TARGET_TIMESTAMP=$(date -d "$TARGET_DATETIME" +%s 2>/dev/null || echo "")

if [ -z "$TARGET_TIMESTAMP" ]; then
  echo "❌ Błąd parsowania daty/godziny: $TARGET_DATETIME"
  echo "START_RECORDING=false" >> "$GITHUB_ENV"
  exit 0
fi

CURRENT_TIMESTAMP=$(date +%s)
DIFF=$((TARGET_TIMESTAMP - CURRENT_TIMESTAMP))

echo "🕒 Zaplanowano na: $TARGET_DATETIME"
echo "🕒 Aktualny czas:  $(date '+%Y-%m-%d %H:%M:%S')"
echo "⏳ Sekundy do startu: $DIFF s"

# 4. Jeśli do startu zostało mniej niż 15 minut (900 s) i nie minęło więcej niż pół godziny (lagi GH)
if [ "$DIFF" -le 900 ] && [ "$DIFF" -ge -1800 ]; then
  echo "🚀 Czas na nagranie!"
  
  # Zapisz parametry dla workflow
  echo "START_RECORDING=true" >> "$GITHUB_ENV"
  echo "REC_DURATION=$DURATION" >> "$GITHUB_ENV"
  echo "REC_BACKUP=$BACKUP" >> "$GITHUB_ENV"
  echo "REC_MEGA=$MEGA" >> "$GITHUB_ENV"
  
  # Usuń pobrane zadanie z pliku, zachowując resztę kolejki
  jq 'del(.[0])' "$FILE" > tmp.json && mv tmp.json "$FILE"
else
  echo "😴 Jeszcze nie czas. Czekam na kolejny cykl crona."
  echo "START_RECORDING=false" >> "$GITHUB_ENV"
fi
