#!/usr/bin/env bash
# Hyprland + hy3 sur Debian 13 (trixie) — installation complète.
#
#   ./install.sh              tout
#   ./install.sh hy3          seulement la recompilation du plugin
#   ./install.sh dotfiles     seulement les dotfiles
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
		;;
	hy3)
		"$REPO_DIR/scripts/03-hy3.sh"
		"$REPO_DIR/scripts/04-dotfiles.sh"
		;;
	dotfiles)
		"$REPO_DIR/scripts/04-dotfiles.sh"
		;;
	*)
		die "Cible inconnue : $TARGET (attendu : all | hy3 | dotfiles)"
		;;
esac

cat <<EOF

$C_GREEN Installation terminée.$C_RESET

 Pour démarrer la session, depuis un TTY (Ctrl+Alt+F2 si besoin) :

     Hyprland

 Raccourcis de départ (Super = touche Windows) :

     Super + Q            terminal (foot)
     Super + R            lanceur (wofi)
     Super + C            fermer la fenêtre
     Super + M            quitter Hyprland
     Super + Entrée       regrouper en onglets (hy3)
     Super + H / V        découper horizontalement / verticalement (hy3)
     Super + flèches      changer de fenêtre
     Super + 1..9         changer de bureau

 La liste complète est dans config/hypr/binds.conf.

$C_YELLOW Après chaque « apt upgrade » qui met à jour Hyprland : lance « hy3-rebuild ».$C_RESET
EOF
