#!/usr/bin/env bash
# Active trixie-backports : Hyprland n'existe pas dans Debian 13 stable.
#
# Vérifié le 14/07/2026 : « Package: hyprland » n'apparaît nulle part dans
# l'index de trixie/main. Le seul Hyprland empaqueté par Debian est celui des
# backports (0.55.2). Sans ce dépôt, aucune des étapes suivantes ne peut aboutir.

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

LIST=/etc/apt/sources.list.d/trixie-backports.sources

step "[1/4] Dépôt trixie-backports"

if [[ -f "$LIST" ]] && grep -q 'trixie-backports' "$LIST"; then
	ok "Déjà activé ($LIST)"
else
	log "Écriture de $LIST"
	# Format deb822, celui que Debian 13 privilégie.
	sudo tee "$LIST" >/dev/null <<-'EOF'
		Types: deb
		URIs: http://deb.debian.org/debian
		Suites: trixie-backports
		Components: main contrib non-free non-free-firmware
		Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
	EOF
	ok "Dépôt ajouté"
fi

log "apt update"
sudo apt-get update -qq

# On refuse de continuer si le dépôt ne remonte pas réellement Hyprland :
# mieux vaut échouer ici, avec un message clair, qu'au milieu de l'installation.
if ! apt-cache policy hyprland 2>/dev/null | grep -q 'trixie-backports'; then
	die "hyprland reste introuvable dans les backports. Vérifie ta connexion réseau et le contenu de $LIST."
fi

ok "Hyprland disponible : $(apt-cache policy hyprland | awk '/Candidat|Candidate/ {print $2}')"
