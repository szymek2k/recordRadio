#!/bin/bash
set -euo pipefail

# --- KONFIGURACJA ---
DAYS_TO_KEEP=3
# Obliczamy próg czasowy w sekundach Unix
CUTOFF_DATE=$(date -d "$DAYS_TO_KEEP days ago 00:00:00" +%s)

echo "[$(date +'%H:%M:%S')] Rozpoczynanie czyszczenia starych uruchomień workflow (starsze niż $DAYS_TO_KEEP dni)..."

# Pobieramy max 500 ostatnich uruchomień w formacie JSON
gh run list --limit 500 --json databaseId,createdAt,status,workflowName | jq -c '.[]' | while read -r run; do
    RUN_ID=$(echo "$run" | jq -r '.databaseId')
    RUN_STATUS=$(echo "$run" | jq -r '.status')
    RUN_DATE=$(echo "$run" | jq -r '.createdAt')
    WORKFLOW_NAME=$(echo "$run" | jq -r '.workflowName')

    # Konwersja daty ISO8601 (z API GitHuba) na sekundy Unix
    RUN_SEC=$(date -d "$RUN_DATE" +%s 2>/dev/null || echo 0)

    # Sprawdzamy warunki: data poprawna, starsza niż cutoff i status "completed"
    if [ "$RUN_SEC" -ne 0 ] && [ "$RUN_SEC" -lt "$CUTOFF_DATE" ] && [ "$RUN_STATUS" = "completed" ]; then
        echo "[$(date +'%H:%M:%S')] Usuwanie: $WORKFLOW_NAME | ID: $RUN_ID | Data: $RUN_DATE"
        # Usunięcie logów i historii uruchomienia z GitHuba
        gh run delete "$RUN_ID" || echo "  [OSTRZEŻENIE] Nie udało się usunąć uruchomienia $RUN_ID"
    fi
done

echo "[$(date +'%H:%M:%S')] Czyszczenie historii zakończone sukcesem."