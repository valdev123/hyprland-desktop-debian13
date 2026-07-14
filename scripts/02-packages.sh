#!/usr/bin/env bash
# Installe Hyprland (backports) + l'écosystème desktop (main).
#
# Chaque paquet de ces listes a été vérifié comme existant réellement dans
# l'index Debian correspondant. N'ajoute rien ici sans avoir vérifié.

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

# --- Hyprland et sa famille : uniquement dans trixie-backports ---------------
BACKPORTS_PKGS=(
	hyprland                     # le compositeur
	hyprland-dev                 # headers + hyprland.pc : indispensables pour compiler hy3
	hyprland-qtutils             # boîtes de dialogue Qt utilisées par Hyprland
	xdg-desktop-portal-hyprland  # partage d'écran, sélecteurs de fichiers
	hyprlock                     # verrouillage d'écran
	hypridle                     # mise en veille sur inactivité
	hyprpaper                    # fond d'écran
	hyprland-backgrounds         # fournit /usr/share/hypr/wall0.png, utilisé par hyprpaper.conf
	hyprpicker                   # pipette à couleurs
	hyprpolkitagent              # agent d'authentification polkit
)

# --- Le reste : présent dans trixie/main -------------------------------------
MAIN_PKGS=(
	# Session
	xdg-desktop-portal xdg-desktop-portal-gtk xwayland qt6-wayland
	# Interface
	waybar wofi foot mako-notifier
	# Outils
	grim slurp wl-clipboard brightnessctl playerctl
	thunar udiskie pavucontrol blueman
	# Audio
	pipewire pipewire-pulse wireplumber
	# Réseau
	network-manager network-manager-gnome
	# Polices et icônes
	fonts-jetbrains-mono fonts-font-awesome fonts-noto-color-emoji papirus-icon-theme
)

# --- Dépendances de compilation de hy3 ---------------------------------------
# hyprland-dev tire la plupart des headers nécessaires, MAIS PAS pango :
# le CMakeLists de hy3 exige les modules pkg-config « pango » et « pangocairo ».
# Sans libpango1.0-dev, le cmake de hy3 échoue. C'est le piège classique.
BUILD_PKGS=(
	git cmake ninja-build g++ pkg-config
	libpango1.0-dev
)

step "[2/6] Installation des paquets"

log "Paquets depuis trixie-backports (${#BACKPORTS_PKGS[@]})"
sudo apt-get install -y -t trixie-backports "${BACKPORTS_PKGS[@]}"
ok "Hyprland $(pkg_upstream_version hyprland) installé"

log "Paquets desktop depuis trixie (${#MAIN_PKGS[@]})"
sudo apt-get install -y "${MAIN_PKGS[@]}"

log "Chaîne de compilation pour hy3 (${#BUILD_PKGS[@]})"
sudo apt-get install -y "${BUILD_PKGS[@]}"

# Sécurise l'audio et le réseau pour la première session.
systemctl --user enable --now pipewire.socket pipewire-pulse.socket wireplumber.service 2>/dev/null || \
	warn "Services pipewire non activés (normal hors session utilisateur ; ils démarreront au login)."

ok "Paquets installés"
