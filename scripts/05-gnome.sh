#!/usr/bin/env bash
# La « plomberie GNOME » : les services sans interface dont les applications ont
# besoin, quel que soit le compositeur.
#
# Ce n'est PAS GNOME Shell. Rien ici ne concurrence Hyprland :
#   - gnome-keyring          trousseau de mots de passe (l'API Secret Service).
#                            Sans lui, beaucoup d'applis redemandent les
#                            identifiants à chaque lancement, ou refusent de
#                            démarrer.
#   - gsettings + dconf      stockage des réglages GTK : thème, police, curseur.
#                            Sans eux, aucun moyen propre de passer les applis
#                            GTK en thème sombre.
#   - xdg-desktop-portal-gnome  sélecteur de fichiers GTK pour les applis
#                            confinées (Flatpak, navigateurs).
#
# Hyprland, Sway et KDE utilisent tous cette couche : elle vient de GNOME, elle
# n'est pas GNOME.

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

GNOME_PKGS=(
	gnome-keyring
	gsettings-desktop-schemas
	dconf-cli
	libglib2.0-bin              # fournit la commande « gsettings »
	xdg-desktop-portal-gnome
	nautilus                    # gestionnaire de fichiers GTK
	adwaita-icon-theme
)

step "[5/6] Plomberie GNOME"

log "Installation (${#GNOME_PKGS[@]} paquets)"
sudo apt-get install -y "${GNOME_PKGS[@]}"

# --- Thème sombre pour les applis GTK ----------------------------------------
# gsettings écrit dans dconf, dans la session de l'utilisateur : pas de sudo ici.
if command -v gsettings >/dev/null; then
	log "Réglages GTK (thème sombre)"
	gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' || true
	gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark' || true
	gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark' || true
	gsettings set org.gnome.desktop.interface cursor-size 24 || true
	ok "Applis GTK en thème sombre"
fi

ok "Plomberie installée"
printf '  %sLe trousseau se déverrouille avec ton mot de passe de session%s (configuré à l'\''étape 6).\n' "$C_DIM" "$C_RESET"
