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
	libpam-gnome-keyring        # déverrouille le trousseau via PAM (recommandation
	                            # de gnome-keyring, donc à citer explicitement
	                            # puisqu'on désactive les recommandations)
	gsettings-desktop-schemas
	dconf-cli
	libglib2.0-bin              # fournit la commande « gsettings »
	nautilus                    # gestionnaire de fichiers GTK
	librsvg2-common             # icônes SVG de nautilus (idem : recommandation)
	adwaita-icon-theme
)

# ⚠️ NE PAS AJOUTER xdg-desktop-portal-gnome ICI.
# Il « Recommends: gnome-shell », qui « Recommends: gdm3 » — et comme apt installe
# les recommandations par défaut, ce seul paquet fait entrer TOUT le bureau GNOME
# (gnome-shell, mutter, gdm3, gnome-control-center… ~60 paquets), qui prend alors
# la main sur le gestionnaire de connexion. Constaté en vrai le 14/07/2026.
#
# Il est de toute façon inutile ici : le portail GNOME sert GNOME Shell. Hyprland
# utilise xdg-desktop-portal-hyprland (partage d'écran) + xdg-desktop-portal-gtk
# (sélecteur de fichiers), tous deux installés à l'étape 2.

step "[5/7] Plomberie GNOME"

log "Installation (${#GNOME_PKGS[@]} paquets)"
# --no-install-recommends : garde-fou contre exactement le problème ci-dessus.
# Toutes les recommandations réellement voulues sont citées dans GNOME_PKGS.
# -t trixie-backports : même raison qu'à l'étape 2 (bibliothèques backportées).
sudo apt-get install -y --no-install-recommends -t trixie-backports "${GNOME_PKGS[@]}"

# Filet : si GNOME Shell est là, c'est qu'une recommandation a encore filtré.
if pkg_installed gnome-shell; then
	warn "gnome-shell est installé — un bureau GNOME complet a été tiré par erreur."
	warn "Nettoyage : sudo apt purge --autoremove gnome-shell gdm3 xdg-desktop-portal-gnome"
fi

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
