#!/usr/bin/env bash
# Applications de travail : VS Code, Google Chrome, Zed.
#
# Étape à part parce qu'aucune des trois n'est empaquetée par Debian : deux
# viennent de dépôts APT tiers, la dernière d'un script d'installation upstream.
# Alacritty et tmux, eux, sont dans main : ils sont posés par 02-packages.sh.

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

KEYRINGS=/etc/apt/keyrings
SOURCES=/etc/apt/sources.list.d
ZED_BIN="$HOME/.local/bin/zed"

step "[7/7] Applications"

# gpg --dearmor et le téléchargement des clés : rien de tout ça n'est garanti
# présent sur une Debian installée au minimum.
for outil in curl gnupg ca-certificates; do
	pkg_installed "$outil" || sudo apt-get install -y "$outil"
done

# Pose la clé et le fichier .sources d'un dépôt tiers, s'ils manquent.
# Renvoie 0 quand quelque chose a été écrit — donc quand « apt update » s'impose.
ajouter_depot() {
	local nom="$1" url_cle="$2" uris="$3" arch="$4"
	local cle="$KEYRINGS/$nom.gpg" src="$SOURCES/$nom.sources"
	local ecrit=1

	if [[ ! -f "$cle" ]]; then
		log "Clé de signature : $nom"
		sudo install -d -m 0755 "$KEYRINGS"
		curl -fsSL "$url_cle" | sudo gpg --dearmor -o "$cle"
		sudo chmod 0644 "$cle"
		ecrit=0
	fi

	if [[ ! -f "$src" ]]; then
		log "Dépôt : $nom"
		sudo tee "$src" >/dev/null <<-EOF
			Types: deb
			URIs: $uris
			Suites: stable
			Components: main
			Architectures: $arch
			Signed-By: $cle
		EOF
		ecrit=0
	fi

	return "$ecrit"
}

# amd64 seul : les deux dépôts publient d'autres architectures, dont apt
# téléchargerait les index pour rien.
MAJ=0

if ajouter_depot vscode \
	https://packages.microsoft.com/keys/microsoft.asc \
	https://packages.microsoft.com/repos/code \
	amd64; then
	MAJ=1
fi

if ajouter_depot google-chrome \
	https://dl.google.com/linux/linux_signing_key.pub \
	https://dl.google.com/linux/chrome/deb/ \
	amd64; then
	MAJ=1
fi

# Le paquet Chrome réinstalle son propre dépôt de son côté, à chaque mise à jour,
# via /opt/google/chrome/cron. Ce fichier est le seul interrupteur qui l'en
# empêche — sans lui, le dépôt finit déclaré deux fois.
if [[ ! -f /etc/default/google-chrome ]]; then
	echo 'repo_add_once=false' | sudo tee /etc/default/google-chrome >/dev/null
	ok "/etc/default/google-chrome (pas de second dépôt)"
fi

if (( MAJ )); then
	log "apt update"
	sudo apt-get update -qq
fi

# --- Installation -------------------------------------------------------------
# On n'installe que ce qui manque : la mise à jour est le travail d'apt upgrade.
MANQUANTS=()
for p in code google-chrome-stable; do
	pkg_installed "$p" || MANQUANTS+=("$p")
done

if (( ${#MANQUANTS[@]} )); then
	log "Installation (${MANQUANTS[*]})"
	sudo apt-get install -y "${MANQUANTS[@]}"
else
	ok "VS Code et Google Chrome déjà installés"
fi

# Les postinst des deux paquets peuvent redéposer leur dépôt au format .list, à
# côté du .sources posé plus haut : apt avertit alors, à chaque update, que le
# dépôt est configuré deux fois. On désarme le doublon sans le supprimer.
for doublon in "$SOURCES/vscode.list" "$SOURCES/google-chrome.list"; do
	[[ -f "$doublon" ]] || continue
	sudo mv "$doublon" "$doublon.disabled"
	warn "$(basename "$doublon") neutralisé : doublon du .sources posé par ce script."
done

# --- Zed ----------------------------------------------------------------------
# Ni paquet Debian, ni dépôt APT : l'installeur officiel pose tout dans ~/.local
# (aucun root) et Zed se met à jour lui-même. « apt upgrade » ne le verra jamais.
if [[ -x "$ZED_BIN" ]] || command -v zed >/dev/null 2>&1; then
	ok "Zed déjà installé"
else
	log "Zed (script officiel zed.dev, hors apt)"
	curl -fsSL https://zed.dev/install.sh | sh
	[[ -x "$ZED_BIN" ]] || die "Zed : l'installeur n'a pas produit $ZED_BIN."
	ok "Zed installé dans ~/.local"
fi

if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
	warn "~/.local/bin n'est pas dans ton PATH — ajoute-le à ton ~/.bashrc pour lancer « zed »."
fi

ok "Applications installées"
