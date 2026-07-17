#!/usr/bin/env bash

login_mega() {
  local max_retries=3

  for ((i=1; i<=max_retries; i++)); do

    if [ -n "${HISTORIA:-}" ]; then
      echo "[$(date +'%H:%M:%S')] Próba logowania do MEGA (próba $i/$max_retries)..." >> "$HISTORIA" 2>&1
    else
      echo "[$(date +'%H:%M:%S')] Próba logowania do MEGA (próba $i/$max_retries)..."
    fi

    if mega-login "$MEGA_EMAIL" "$MEGA_PASSWORD" >/dev/null 2>&1; then

      if [ -n "${HISTORIA:-}" ]; then
        echo "[$(date +'%H:%M:%S')] Logowanie do MEGA zakończone sukcesem." >> "$HISTORIA" 2>&1
      else
        echo "[$(date +'%H:%M:%S')] Logowanie do MEGA zakończone sukcesem."
      fi

      return 0
    fi

    if [ "$i" -lt "$max_retries" ]; then

      if [ -n "${HISTORIA:-}" ]; then
        echo "[$(date +'%H:%M:%S')] Logowanie nieudane. Ponawiam za 30 sekund..." >> "$HISTORIA" 2>&1
      else
        echo "[$(date +'%H:%M:%S')] Logowanie nieudane. Ponawiam za 30 sekund..."
      fi

      sleep 30
    fi

  done

  if [ -n "${HISTORIA:-}" ]; then
    echo "[$(date +'%H:%M:%S')] BŁĄD: Nie udało się zalogować do MEGA po $max_retries próbach." >> "$HISTORIA" 2>&1
  else
    echo "[$(date +'%H:%M:%S')] BŁĄD: Nie udało się zalogować do MEGA po $max_retries próbach."
  fi

  return 1
}

ensure_mega_login() {
  mega-whoami >/dev/null 2>&1 || login_mega
}