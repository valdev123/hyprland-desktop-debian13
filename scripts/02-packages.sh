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
	waybar wofi alacritty mako-notifier
	# Shell
	zsh zsh-autosuggestions zsh-syntax-highlighting
	# Outils
	grim slurp wl-clipboard brightnessctl playerctl
	tmux
	jq                       # lit « hyprctl monitors -j » dans bin/hypr-monitors
	rsync                    # exigé par l'auto-update de Zed, installé en 07-apps.sh
	thunar udiskie pavucontrol blueman
	# Audio
	pipewire pipewire-pulse wireplumber
	# Réseau
	network-manager network-manager-gnome
	# Polices et icônes
	fonts-jetbrains-mono fonts-font-awesome fonts-noto-color-emoji papirus-icon-theme
	curl                     # télécharge la Nerd Font, plus bas
)

# --- Dépendances de compilation de hy3 ---------------------------------------
# hyprland-dev tire la plupart des headers nécessaires, MAIS PAS pango :
# le CMakeLists de hy3 exige les modules pkg-config « pango » et « pangocairo ».
# Sans libpango1.0-dev, le cmake de hy3 échoue. C'est le piège classique.
BUILD_PKGS=(
	git cmake ninja-build g++ pkg-config
	libpango1.0-dev
)

step "[2/7] Installation des paquets"

# POURQUOI « -t trixie-backports » PARTOUT, Y COMPRIS POUR LES PAQUETS DE MAIN
# ---------------------------------------------------------------------------
# Hyprland vient des backports et tire avec lui des versions backportées de
# bibliothèques centrales : libpipewire-0.3-0t64 (1.4.9 au lieu de 1.4.2),
# libxkbcommon0 (1.13.1 au lieu de 1.7.0)…
#
# Or les paquets de trixie/main qui se lient à ces bibliothèques exigent une
# égalité STRICTE de version. « pipewire » de main dépend de
# libpipewire-0.3-modules (= 1.4.2-1), lui-même de libpipewire-0.3-0t64
# (= 1.4.2-1) : impossible à satisfaire une fois la 1.4.9 installée. apt s'arrête
# sur « Reached two conflicting decisions ».
#
# Le « -t » ne force rien : il élève la priorité des backports. apt y prend donc
# pipewire, wireplumber et libxkbregistry0 (qui DOIVENT en venir) et laisse le
# reste — waybar, wofi, alacritty… — dans main, où c'est leur seule origine.
APT_TARGET=(-t trixie-backports)

log "Hyprland et son écosystème (${#BACKPORTS_PKGS[@]})"
sudo apt-get install -y "${APT_TARGET[@]}" "${BACKPORTS_PKGS[@]}"
ok "Hyprland $(pkg_upstream_version hyprland) installé"

log "Paquets desktop (${#MAIN_PKGS[@]})"
sudo apt-get install -y "${APT_TARGET[@]}" "${MAIN_PKGS[@]}"

log "Chaîne de compilation pour hy3 (${#BUILD_PKGS[@]})"
sudo apt-get install -y "${APT_TARGET[@]}" "${BUILD_PKGS[@]}"

# --- Police à glyphes ---------------------------------------------------------
# Aucune Nerd Font n'est empaquetée par Debian, et waybar affiche des icônes :
# sans elle, la barre se remplit de carrés. Installée dans le profil utilisateur,
# donc sans sudo.
#
# L'URL « latest » évite de figer une version, pour la même raison que le tag hy3
# n'est pas codé en dur : la police n'a aucun lien avec la version d'Hyprland.
NERD_DIR="$HOME/.local/share/fonts/JetBrainsMonoNerdFont"
NERD_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz"

log "Police JetBrainsMono Nerd Font"
if fc-list : family | grep -q 'JetBrainsMono Nerd Font'; then
	ok "JetBrainsMono Nerd Font : déjà installée"
else
	NERD_ARCHIVE="$(mktemp -t jetbrainsmono-nf-XXXXXX.tar.xz)"
	if curl -fsSL --retry 2 -o "$NERD_ARCHIVE" "$NERD_URL"; then
		mkdir -p "$NERD_DIR"
		# Deux des six familles de l'archive, qui en pèse 230 Mo une fois posée.
		# La variante « Mono » rend ses icônes sur une seule cellule : c'est
		# celle du terminal. L'autre les rend sur deux, ce qui va aux barres et
		# aux menus mais désaligne un terminal.
		tar -xJf "$NERD_ARCHIVE" -C "$NERD_DIR" --wildcards \
			'JetBrainsMonoNerdFont-*.ttf' 'JetBrainsMonoNerdFontMono-*.ttf'
		fc-cache -f "$NERD_DIR" >/dev/null
		ok "JetBrainsMono Nerd Font installée dans $NERD_DIR"
	else
		# Pas de « die » : tout le reste de l'installation fonctionne sans elle.
		warn "Téléchargement de la Nerd Font échoué — les icônes de waybar s'afficheront en carrés. Relance cette étape une fois le réseau revenu."
	fi
	rm -f "$NERD_ARCHIVE"
fi

# --- zsh comme shell de connexion ---------------------------------------------
# Ici et pas dans 04-dotfiles.sh, qui n'a pas le ticket sudo : « chsh » sur son
# propre compte réclame sinon le mot de passe utilisateur.
ZSH_BIN="$(command -v zsh || true)"
SHELL_ACTUEL="$(getent passwd "$USER" | cut -d: -f7)"

if [[ -z "$ZSH_BIN" ]]; then
	warn "zsh introuvable après installation — shell de connexion laissé sur $SHELL_ACTUEL."
elif [[ "$SHELL_ACTUEL" == "$ZSH_BIN" ]]; then
	ok "shell de connexion : déjà $ZSH_BIN"
else
	sudo chsh -s "$ZSH_BIN" "$USER"
	ok "shell de connexion : $SHELL_ACTUEL → $ZSH_BIN (effectif à la prochaine connexion)"
fi

# Sécurise l'audio et le réseau pour la première session.
systemctl --user enable --now pipewire.socket pipewire-pulse.socket wireplumber.service 2>/dev/null || \
	warn "Services pipewire non activés (normal hors session utilisateur ; ils démarreront au login)."

ok "Paquets installés"
