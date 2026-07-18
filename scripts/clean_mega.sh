#!/bin/bash
set -euo pipefail

# Przyjmij parametry przekazane z workflow
TARGET_DIR="$1"
HISTORIA="$2"

export TZ="Europe/Warsaw"

# =================================================================
# --- INTELIGENTNY LOCK-FILE Z COOLDOWNEM (MAX 1 GODZINA) ---
# =================================================================
NOW=$(date +%s)
# Szukamy jakiegokolwiek istniejącego pliku lock w głównym katalogu MEGA
EXISTING_LOCK=$(mega-find / | grep -E '^/clean_mega_global_.*\.lock$' | head -n 1 || true)

if [ -n "$EXISTING_LOCK" ]; then
  LOCK_FILENAME=$(basename "$EXISTING_LOCK")
  # Wyciągamy timestamp Unix (ostatni ciąg cyfr przed .lock)
  LOCK_EPOCH=$(echo "$LOCK_FILENAME" | sed -E 's/.*_([0-9]+)\.lock$/\1/')

  # Sprawdzenie czy wyciągnięta wartość jest prawidłową liczbą
  if [[ "$LOCK_EPOCH" =~ ^[0-9]+$ ]]; then
    AGE=$((NOW - LOCK_EPOCH))

    # 1200 sekund = 20 minut
    if [ "$AGE" -gt 1200 ]; then
      echo "[$(date +'%H:%M:%S')] [RETENCJA] Wykryto przedawnioną blokadę (Wiek: ${AGE}s > 1200). Usuwam martwy lock." | tee -a "$HISTORIA"
      mega-rm "$EXISTING_LOCK" >> "$HISTORIA" 2>&1 || true
    else
      echo "[$(date +'%H:%M:%S')] [RETENCJA] UWAGA: Inny workflow sprząta chmurę. Blokada jest aktywna (Wiek: ${AGE}s). Pomijam krok." | tee -a "$HISTORIA"
      exit 0
    fi
  else
    # Na wypadek, gdyby ktoś ręcznie stworzył plik o błędnej nazwie
    echo "[$(date +'%H:%M:%S')] [RETENCJA] Wykryto uszkodzony plik blokady. Usuwam go dla bezpieczeństwa." | tee -a "$HISTORIA"
    mega-rm "$EXISTING_LOCK" >> "$HISTORIA" 2>&1 || true
  fi
fi

# Tworzenie nowego dynamicznego locka (Format: clean_mega_global_RRRR-MM-DD_GG-MM-SS_TIMESTAMP.lock)
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
LOCK_FILE="/clean_mega_global_${TIMESTAMP}_${NOW}.lock"

echo "[$(date +'%H:%M:%S')] [RETENCJA] Zakładanie nowej globalnej blokady: $LOCK_FILE" | tee -a "$HISTORIA"
touch "/tmp/$(basename "$LOCK_FILE")"
if ! mega-put "/tmp/$(basename "$LOCK_FILE")" / >> "$HISTORIA" 2>&1; then
  echo "[$(date +'%H:%M:%S')] [RETENCJA] Błąd zapisu blokady na MEGA. Dla bezpieczeństwa pomijam czyszczenie." | tee -a "$HISTORIA"
  exit 0
fi

# Jeśli skrypt padnie w trakcie pętli, trap usunie ten konkretny, dynamiczny plik
trap 'mega-rm "$LOCK_FILE" >> "$HISTORIA" 2>&1 || true' EXIT TERM INT
# =================================================================


echo "[$(date +'%H:%M:%S')] [RETENCJA] Uruchamianie czyszczenia i segregacji dla: $TARGET_DIR..." | tee -a "$HISTORIA"
# --- ZMIANA 1: Próg retencji zmieniony z 14 na 10 dni ---
TEN_DAYS_AGO=$(date -d "10 days ago 00:00:00" +%s)

# --- ZMIANA 2: Tworzenie folderu weekend jako dedykowanego podfolderu ---
mega-mkdir "$TARGET_DIR/weekend" >> "$HISTORIA" 2>&1 || true

mega-find "$TARGET_DIR" | while read -r remote_file; do
  [ -z "$remote_file" ] && continue

  # Ignoruj pliki, które JUŻ SĄ w podfolderze weekend
  if [[ "$remote_file" == *"/weekend/"* ]]; then
    continue
  fi

  # Szukanie wzorca daty YYYY-MM-DD w nazwie ścieżki pliku
  if [[ "$remote_file" =~ ([0-9]{4}-[0-9]{2}-[0-9]{2}) ]]; then
    FILE_DATE="${BASH_REMATCH[1]}"

    FILE_SEC=$(date -d "$FILE_DATE" +%s 2>/dev/null || echo 0)
    DAY_OF_WEEK=$(date -d "$FILE_DATE" +%u 2>/dev/null || echo 0) # 1=Pon, ..., 7=Niedz

    if [ "$FILE_SEC" -ne 0 ] && [ "$DAY_OF_WEEK" -ne 0 ]; then

      # Sprawdzamy pliki starsze niż 10 dni
      if [ "$FILE_SEC" -lt "$TEN_DAYS_AGO" ]; then

        # --- ZMIANA 3: Jeśli to plik tekstowy lub log, usuwamy go bez względu na dzień tygodnia ---
        if [[ "$remote_file" == *.txt || "$remote_file" == *.log ]]; then
          echo "[$(date +'%H:%M:%S')] [RETENCJA] Usuwanie starego pliku logu: $remote_file (Data: $FILE_DATE)" | tee -a "$HISTORIA"
          mega-rm "$remote_file" >> "$HISTORIA" 2>&1 || echo "Błąd usuwania logu z MEGA" >> "$HISTORIA"

        # Dla pozostałych plików (np. .mp3) stosujemy standardowy podział na tydzień/weekend
        else
          # Poniedziałek - Czwartek (Dni 1-4) -> USUWANIE
          if [ "$DAY_OF_WEEK" -ge 1 ] && [ "$DAY_OF_WEEK" -le 4 ]; then
            echo "[$(date +'%H:%M:%S')] [RETENCJA] Usuwanie starego pliku z tygodnia: $remote_file (Data: $FILE_DATE)" | tee -a "$HISTORIA"
            mega-rm "$remote_file" >> "$HISTORIA" 2>&1 || echo "Błąd usuwania pliku z MEGA" >> "$HISTORIA"

          # Piątek - Niedziela (Dni 5-7) -> PRZENOSZENIE DO PODFOLDERU WEEKEND
          elif [ "$DAY_OF_WEEK" -ge 5 ] && [ "$DAY_OF_WEEK" -le 7 ]; then
            echo "[$(date +'%H:%M:%S')] [RETENCJA] Przenoszenie starego pliku weekendowego: $remote_file -> do /weekend/" | tee -a "$HISTORIA"
            mega-mv "$remote_file" "$TARGET_DIR/weekend/" >> "$HISTORIA" 2>&1 || echo "Błąd przenoszenia pliku na MEGA" >> "$HISTORIA"
          fi
        fi

      fi
    fi
  fi
done

echo "[$(date +'%H:%M:%S')] [RETENCJA] Czyszczenie i segregacja zakończone pomyślnie." | tee -a "$HISTORIA"