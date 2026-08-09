#!/usr/bin/env bash
# Écran de connexion : greetd + tuigreet.
#
# Remplace la connexion en TTY par un écran avec menu de session. Les sessions
# proposées sont lues dans /usr/share/wayland-sessions/ : le paquet Debian
# d'Hyprland y dépose hyprland.desktop, Sway y dépose sway.desktop. Les deux
# apparaîtront donc automatiquement, sans rien déclarer.

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

CONF=/etc/greetd/config.toml
PAM=/etc/pam.d/greetd

step "[6/6] Écran de connexion (greetd + tuigreet)"

log "Installation"
# « -t trixie-backports » par cohérence avec les étapes 2 et 5 : greetd n'en a pas
# besoin aujourd'hui, mais ses dépendances peuvent basculer le jour où Hyprland
# backportera une bibliothèque de plus.
sudo apt-get install -y -t trixie-backports greetd tuigreet

# --- Configuration ------------------------------------------------------------
# vt = 7, délibérément : les TTY 1 à 6 gardent leur invite de connexion texte.
# C'est le filet de sécurité — si une session graphique refuse de démarrer,
# Ctrl+Alt+F2 donne toujours un shell.
if [[ -f "$CONF" ]]; then
	sudo cp -n "$CONF" "$CONF.bak" && ok "Config d'origine sauvegardée : $CONF.bak"
fi

GREETER_USER="_greetd"
id "$GREETER_USER" &>/dev/null || GREETER_USER="greeter"
id "$GREETER_USER" &>/dev/null || die "Aucun utilisateur greeter (_greetd) créé par le paquet greetd."

sudo mkdir -p /etc/greetd
sudo tee "$CONF" >/dev/null <<EOF
# Généré par hyprland-desktop-debian13/scripts/06-greetd.sh

[terminal]
# TTY 7 : les TTY 1-6 restent des consoles texte utilisables (Ctrl+Alt+F2).
vt = 7

[default_session]
# --remember / --remember-user-session : retient le dernier utilisateur et sa session.
# Les sessions viennent de /usr/share/wayland-sessions (Hyprland, Sway…).
command = "tuigreet --time --remember --remember-user-session --asterisks"
user = "$GREETER_USER"
EOF
ok "Config écrite : $CONF (utilisateur greeter : $GREETER_USER)"

# --- Déverrouillage automatique du trousseau ---------------------------------
# Sans ça, gnome-keyring redemande un mot de passe à chaque session, en plus de
# celui de la connexion. Les deux lignes sont « optional » : si le module manque
# ou échoue, PAM les ignore — elles ne peuvent pas te verrouiller dehors.
if [[ -f "$PAM" ]] && dpkg-query -W -f='${Status}' gnome-keyring 2>/dev/null | grep -q 'installed'; then
	if grep -q pam_gnome_keyring "$PAM"; then
		ok "Trousseau déjà branché sur PAM"
	else
		sudo cp -n "$PAM" "$PAM.bak"
		printf 'auth       optional     pam_gnome_keyring.so\nsession    optional     pam_gnome_keyring.so auto_start\n' \
			| sudo tee -a "$PAM" >/dev/null
		ok "Trousseau déverrouillé par le mot de passe de session (sauvegarde : $PAM.bak)"
	fi
fi

# --- Activation ---------------------------------------------------------------
# Un seul gestionnaire de connexion peut détenir /etc/systemd/system/display-manager.service.
# S'il est déjà pris (par gdm3, lightdm…), « systemctl enable greetd » échoue —
# et il faut le dire, pas l'avaler. C'est précisément ce qui s'était produit ici :
# xdg-desktop-portal-gnome avait fait installer gdm3, qui squattait le lien.
DM_LINK=/etc/systemd/system/display-manager.service

if [[ -L "$DM_LINK" ]]; then
	CURRENT_DM="$(readlink "$DM_LINK")"
	if [[ ! -e "$DM_LINK" ]]; then
		# Lien mort : la cible a été désinstallée (typiquement gdm3 purgé) mais
		# systemd garde le lien, et « enable greetd » refuse alors de l'écraser.
		log "Lien mort détecté ($(basename "$CURRENT_DM") a été désinstallé) — suppression"
		sudo rm -f "$DM_LINK"
	elif [[ "$CURRENT_DM" != *greetd* ]]; then
		warn "Un autre gestionnaire de connexion occupe la place : $(basename "$CURRENT_DM")"
		warn "Désactive-le d'abord (p. ex. : sudo apt purge --autoremove gdm3), puis relance :"
		warn "    ./install.sh greetd"
		die "greetd non activé."
	fi
fi

# enable, pas start : le changement prend effet au prochain démarrage, pour ne pas
# tuer la session graphique en cours. Les erreurs remontent (pas de /dev/null).
if sudo systemctl enable greetd.service; then
	ok "greetd activé au démarrage"
else
	die "Échec de « systemctl enable greetd » — voir le message ci-dessus."
fi

printf '\n  %sAu prochain redémarrage%s : écran de connexion, menu de session (Hyprland / Sway).\n' "$C_YELLOW" "$C_RESET"
printf '  Pour revenir à la connexion en TTY : %ssudo systemctl disable greetd%s\n' "$C_DIM" "$C_RESET"
