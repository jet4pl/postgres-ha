#!/bin/bash
set -e

# Ścieżka do katalogu danych PostgreSQL
DATA_DIR="/var/lib/postgresql/data"

# Jeśli katalog jest pusty, przeprowadzamy konfigurację wstępną
if [ -z "$(ls -A "$DATA_DIR")" ]; then
    if [ "$PG_MODE" = "master" ]; then
        echo "=== INICJALIZACJA WĘZŁA MASTER ==="
        
        # Uruchomienie standardowego skryptu inicjalizacyjnego PostgreSQL
        /usr/local/bin/docker-entrypoint.sh postgres &
        PID=$!
        
        # Oczekiwanie na uruchomienie bazy danych
        until pg_isready -h localhost -p 5432; do sleep 1; done
        
        # Konfiguracja uprawnień replikacji w pg_hba.conf
        echo "host replication $PG_REP_USER 0.0.0.0/0 scram-sha-256" >> "$DATA_DIR/pg_hba.conf"
        
        # Tworzenie dedykowanego użytkownika do replikacji strumieniowej
        psql -U "$POSTGRES_USER" -d postgres -c "CREATE ROLE $PG_REP_USER WITH REPLICATION PASSWORD '$PG_REP_PASSWORD' LOGIN;"
        
        # Przeładowanie konfiguracji
        pg_ctl reload
        
        # Oczekiwanie na zakończenie procesu tła
        kill $PID
        wait $PID

    elif [ "$PG_MODE" = "replica" ]; then
        echo "=== INICJALIZACJA WĘZŁA REPLIKI (STANDBY) ==="
        
        # Oczekiwanie aż Master będzie dostępny w sieci
        until nc -z -w 2 "$PG_MASTER_HOST" 5432; do
            echo "Oczekiwanie na połączenie z Masterem ($PG_MASTER_HOST)..."
            sleep 2
        done
        
        # Pobieranie bazy początkowej z Mastera (pg_basebackup)
        PGPASSWORD="$PG_REP_PASSWORD" pg_basebackup \
            -h "$PG_MASTER_HOST" \
            -p 5432 \
            -D "$DATA_DIR" \
            -U "$PG_REP_USER" \
            -v \
            -P \
            -X stream \
            -R # Flaga -R automatycznie tworzy standby.signal i konfiguruje replikację
            
        echo "=== Klonowanie zakończone. Węzeł skonfigurowany jako Hot Standby ==="
    fi
fi

# Uruchomienie właściwego procesu PostgreSQL
exec /usr/local/bin/docker-entrypoint.sh "$@"

