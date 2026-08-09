#!/usr/bin/env bash
# Fonctions partagées par les scripts d'installation.

set -euo pipefail

# --- Couleurs (désactivées si la sortie n'est pas un terminal) -----------------
if [[ -t 1 ]]; then
	C_RESET=$'\033[0m'; C_BLUE=$'\033[1;34m'; C_GREEN=$'\033[1;32m'
	C_YELLOW=$'\033[1;33m'; C_RED=$'\033[1;31m'; C_DIM=$'\033[2m'
else
	C_RESET=""; C_BLUE=""; C_GREEN=""; C_YELLOW=""; C_RED=""; C_DIM=""
fi

log()   { printf '%s==>%s %s\n' "$C_BLUE"   "$C_RESET" "$*"; }
ok()    { printf '%s  ✓%s %s\n' "$C_GREEN"  "$C_RESET" "$*"; }
warn()  { printf '%s  !%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }
die()   { printf '%s  ✗%s %s\n' "$C_RED"    "$C_RESET" "$*" >&2; exit 1; }
step()  { printf '\n%s%s%s\n' "$C_DIM" "$*" "$C_RESET"; }

# --- Garde-fous ---------------------------------------------------------------

# Les scripts s'exécutent en utilisateur normal et appellent sudo au besoin.
# Tout lancer en root planterait les dotfiles dans /root.
require_not_root() {
	[[ ${EUID} -ne 0 ]] || die "Ne lance pas ce script en root. Utilise ton compte normal ; sudo est appelé quand c'est nécessaire."
}

require_debian_13() {
	[[ -r /etc/os-release ]] || die "/etc/os-release introuvable : ce n'est pas une Debian."
	# shellcheck disable=SC1091
	. /etc/os-release
	if [[ "${ID:-}" != "debian" || "${VERSION_ID:-}" != "13" ]]; then
		warn "Système détecté : ${PRETTY_NAME:-inconnu} — ce dépôt cible Debian 13 (trixie)."
		if [[ "${HY3_FORCE:-0}" != "1" ]]; then
			die "Interrompu. Relance avec HY3_FORCE=1 pour passer outre."
		fi
	fi
}

# Demande le ticket sudo une seule fois, en début de course, pour ne pas
# interrompre l'installation par une invite de mot de passe au milieu.
sudo_prime() {
	log "Élévation des privilèges (sudo)"
	sudo -v || die "sudo indisponible."
	# Maintient le ticket vivant tant que le script tourne.
	while true; do sudo -n true; sleep 50; kill -0 "$$" 2>/dev/null || exit; done 2>/dev/null &
}

# --- Matériel -----------------------------------------------------------------

# Vendeur du GPU qui pilote l'affichage : amd | nvidia | intel | inconnu.
#
# On interroge sysfs et non « lspci » : c'est le noyau qui répond, sans dépendre
# de pciutils, et /sys/class/drm ne liste que les cartes réellement pilotées par
# un driver DRM — donc exactement celles qu'Hyprland pourra utiliser.
#
# (Au passage : « lspci -d ::0300 -d ::0302 » ne fonctionnerait pas, lspci ne
# retient que le dernier -d au lieu de les cumuler.)
detect_gpu() {
	# HY3_GPU : force la valeur, seul moyen d'exercer une branche sans le matériel.
	if [[ -n "${HY3_GPU:-}" ]]; then printf '%s\n' "$HY3_GPU"; return; fi

	local vendors=""
	for f in /sys/class/drm/card*/device/vendor; do
		[[ -r "$f" ]] || continue
		vendors+="$(<"$f") "
	done

	# NVIDIA l'emporte sur une machine hybride : c'est lui qui impose des
	# variables d'environnement, l'iGPU Intel ou AMD n'en demande aucune.
	case "$vendors" in
		*0x10de*) printf 'nvidia\n' ;;
		*0x1002*) printf 'amd\n' ;;
		*0x8086*) printf 'intel\n' ;;
		*)        printf 'inconnu\n' ;;
	esac
}

# Disposition du clavier : « layout variant », le variant pouvant être vide.
# /etc/default/keyboard fait autorité sur Debian ; localectl n'est qu'un repli.
detect_keyboard() {
	# HY3_KEYBOARD=us, ou « fr latin9 » : force la valeur.
	if [[ -n "${HY3_KEYBOARD:-}" ]]; then printf '%s\n' "$HY3_KEYBOARD"; return; fi

	local layout="" variant=""
	if [[ -r /etc/default/keyboard ]]; then
		# shellcheck disable=SC1091
		. /etc/default/keyboard
		layout="${XKBLAYOUT:-}"; variant="${XKBVARIANT:-}"
	fi

	if [[ -z "$layout" ]] && command -v localectl >/dev/null; then
		layout="$(localectl status 2>/dev/null | awk '/X11 Layout/ {print $3}')"
		variant="$(localectl status 2>/dev/null | awk '/X11 Variant/ {print $3}')"
	fi

	printf '%s %s\n' "${layout:-fr}" "$variant"
}

# Vrai sur un portable. La batterie prime : elle est ce qui justifie réellement
# la suspension automatique, là où le châssis DMI est souvent mal renseigné.
is_laptop() {
	# HY3_LAPTOP=1 ou 0 : force la réponse dans les deux sens.
	if [[ -n "${HY3_LAPTOP:-}" ]]; then [[ "$HY3_LAPTOP" == "1" ]]; return; fi

	compgen -G '/sys/class/power_supply/BAT*' >/dev/null && return 0

	# 8-14 : portable, notebook, sub-notebook… ; 30-32 : tablette et convertibles.
	case "$(cat /sys/class/dmi/id/chassis_type 2>/dev/null || true)" in
		8|9|10|11|14|30|31|32) return 0 ;;
		*)                     return 1 ;;
	esac
}

# --- Utilitaires apt ----------------------------------------------------------

pkg_installed() { dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q '^install ok installed$'; }

# Version d'un paquet installé, débarrassée de l'habillage Debian.
# 0.55.2+ds-1~bpo13+1  ->  0.55.2
pkg_upstream_version() {
	local v
	v="$(dpkg-query -W -f='${Version}' "$1" 2>/dev/null)" || return 1
	v="${v%%+ds*}"; v="${v%%-*}"; v="${v%%~*}"
	# Retire un éventuel epoch (1:0.55.2).
	printf '%s\n' "${v##*:}"
}
