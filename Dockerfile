FROM postgres:17-bookworm

# Instalacja podstawowych narzędzi sieciowych do diagnostyki
RUN apt-get update && apt-get install -y iputils-ping netcat-traditional && rm -rf /var/lib/apt/lists/*

# Kopiowanie skryptu startowego do kontenera
COPY entrypoint.sh /usr/local/bin/custom-entrypoint.sh
RUN chmod +x /usr/local/bin/custom-entrypoint.sh

# Definiujemy nasz skrypt jako główny punkt startowy
ENTRYPOINT ["/usr/local/bin/custom-entrypoint.sh"]
CMD ["postgres"]

