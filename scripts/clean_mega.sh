#!/bin/bash
set -euo pipefail

# Przyjmij parametry przekazane z workflow
TARGET_DIR="$1"
HISTORIA="$2"

export TZ="Europe/Warsaw"

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