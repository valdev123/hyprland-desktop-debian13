#!/usr/bin/env bash
# Hyprland + hy3 sur Debian 13 (trixie) — installation complète.
#
#   ./install.sh              tout
#   ./install.sh packages     seulement les paquets (backports + apt + shell zsh)
#   ./install.sh hy3          seulement la recompilation du plugin
#   ./install.sh dotfiles     seulement les dotfiles
#   ./install.sh gnome        seulement la plomberie GNOME (trousseau, thème GTK)
#   ./install.sh greetd       seulement l'écran de connexion
#   ./install.sh apps         seulement les applications (VS Code, Chrome, Zed)
#
# Idempotent : relancer le script est sans danger.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$REPO_DIR/lib/common.sh"

require_not_root
require_debian_13

TARGET="${1:-all}"

case "$TARGET" in
	all)
		sudo_prime
		"$REPO_DIR/scripts/01-backports.sh"
		"$REPO_DIR/scripts/02-packages.sh"
		"$REPO_DIR/scripts/03-hy3.sh"
		"$REPO_DIR/scripts/04-dotfiles.sh"
		"$REPO_DIR/scripts/05-gnome.sh"
		"$REPO_DIR/scripts/06-greetd.sh"
		"$REPO_DIR/scripts/07-apps.sh"
		;;
	packages)
		sudo_prime
		# 01 d'abord : sans les backports, apt ne voit aucun paquet Hyprland.
		"$REPO_DIR/scripts/01-backports.sh"
		"$REPO_DIR/scripts/02-packages.sh"
		;;
	hy3)
		"$REPO_DIR/scripts/03-hy3.sh"
		"$REPO_DIR/scripts/04-dotfiles.sh"
		;;
	dotfiles)
		"$REPO_DIR/scripts/04-dotfiles.sh"
		;;
	gnome)
		sudo_prime
		"$REPO_DIR/scripts/05-gnome.sh"
		;;
	greetd)
		sudo_prime
		"$REPO_DIR/scripts/06-greetd.sh"
		;;
	apps)
		sudo_prime
		"$REPO_DIR/scripts/07-apps.sh"
		;;
	*)
		die "Cible inconnue : $TARGET (attendu : all | packages | hy3 | dotfiles | gnome | greetd | apps)"
		;;
esac

cat <<EOF

$C_GREEN Installation terminée.$C_RESET

 Redémarre : l'écran de connexion (greetd) s'affiche et propose Hyprland
 ou Sway au menu de session.

 Sans redémarrer, depuis un TTY (Ctrl+Alt+F2) : lance « Hyprland ».

 Raccourcis de départ (Super = touche Windows), calqués sur i3 :

     Super + Entrée       terminal (alacritty, qui ouvre tmux sous zsh)
     Super + D            lanceur (wofi)
     Super + Shift + Q    fermer la fenêtre
     Super + Shift + E    menu de session (verrouiller, éteindre, redémarrer…)
     Super + Shift + C    recharger la config
     Super + H / V        découper horizontalement / verticalement (hy3)
     Super + W            regrouper en onglets (hy3)
     Super + flèches      changer de fenêtre
     Super + 1 … 9        changer de bureau (& é " … sur AZERTY)

 La liste complète est dans config/hypr/binds.conf — sauf ce qui dépend de la
 disposition du clavier, généré dans config/hypr/keyboard.conf.

 Si un second écran est mal placé : « hypr-monitors save » fige la disposition
 courante, puis « hyprctl reload ».

 Tes réglages à toi : les fichiers « local » de ~/.config (hypr/local.conf,
 waybar/local.jsonc, waybar/local.css, mako/local, alacritty/local.toml,
 tmux/local.conf, zsh/local.zsh). Ils sont lus en dernier, donc ils gagnent —
 et ils ne sont ni écrasés ni commités.

$C_YELLOW Après chaque « apt upgrade » qui met à jour Hyprland : lance « hy3-rebuild ».
 Et s'il met à jour tmux : « tmux kill-server », sinon le serveur resté en
 mémoire refuse les clients de la nouvelle version.$C_RESET
EOF
