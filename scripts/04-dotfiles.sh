#!/usr/bin/env bash
# Déploie les dotfiles par liens symboliques vers ~/.config.
#
# Les liens pointent vers le dépôt : tu édites les fichiers ici, git suit les
# modifications, et Hyprland les relit à chaud. Toute config préexistante est
# sauvegardée, jamais écrasée en silence.

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_SRC="$REPO_DIR/config"
CONFIG_DST="${XDG_CONFIG_HOME:-$HOME/.config}"
BACKUP_DIR="$CONFIG_DST/../.config-backup-$(date +%Y%m%d-%H%M%S)"
PLUGIN_SO="${XDG_DATA_HOME:-$HOME/.local/share}/hyprland/plugins/libhy3.so"

step "[4/6] Dotfiles"

mkdir -p "$CONFIG_DST"

for src in "$CONFIG_SRC"/*; do
	name="$(basename "$src")"
	dst="$CONFIG_DST/$name"

	# Déjà le bon lien : rien à faire.
	if [[ -L "$dst" && "$(readlink -f "$dst")" == "$(readlink -f "$src")" ]]; then
		ok "$name (déjà lié)"
		continue
	fi

	# Quelque chose d'autre existe : on le met de côté avant de toucher à quoi que ce soit.
	if [[ -e "$dst" || -L "$dst" ]]; then
		mkdir -p "$BACKUP_DIR"
		mv "$dst" "$BACKUP_DIR/$name"
		warn "$name existait → sauvegardé dans $BACKUP_DIR/"
	fi

	ln -s "$src" "$dst"
	ok "$name → $src"
done

# --- Chemin du plugin, résolu pour cette machine ------------------------------
# Hyprland n'accepte pas de variable d'environnement dans « plugin = » : on écrit
# donc le chemin absolu dans un fichier à part, hors du suivi git.
PLUGINS_CONF="$CONFIG_SRC/hypr/plugins.conf"
if [[ -f "$PLUGIN_SO" ]]; then
	cat > "$PLUGINS_CONF" <<-EOF
		# Généré par scripts/04-dotfiles.sh — ne pas versionner (voir .gitignore).
		# Régénéré par « hy3-rebuild ».
		plugin = $PLUGIN_SO
	EOF
	ok "plugins.conf → $PLUGIN_SO"
else
	# Un « plugin = » pointant dans le vide empêche Hyprland de démarrer :
	# mieux vaut un fichier vide qu'une session cassée.
	cat > "$PLUGINS_CONF" <<-EOF
		# hy3 n'est pas encore compilé : lance scripts/03-hy3.sh puis « hy3-rebuild ».
	EOF
	warn "libhy3.so introuvable — plugins.conf laissé vide (Hyprland démarrera sans hy3)."
fi

# --- Variables propres au GPU, résolues pour cette machine --------------------
# Hyprland ne détecte pas le GPU tout seul : sur NVIDIA il faut lui poser des
# variables d'environnement, sur AMD et Intel il ne faut surtout rien poser. On
# écrit donc un fichier à part, hors du suivi git (même motif que plugins.conf) :
# le dépôt reste ainsi valable sur une machine dont le GPU n'est pas celui-ci.
GPU_CONF="$CONFIG_SRC/hypr/gpu.conf"
GPU="$(detect_gpu)"

case "$GPU" in
	nvidia)
		cat > "$GPU_CONF" <<-'EOF'
			# Généré par scripts/04-dotfiles.sh — ne pas versionner (voir .gitignore).
			# GPU NVIDIA détecté.

			env = LIBVA_DRIVER_NAME,nvidia
			env = __GLX_VENDOR_LIBRARY_NAME,nvidia

			# Le curseur matériel est ce qui casse le plus souvent sur NVIDIA
			# (curseur invisible ou clignotant).
			cursor {
			    no_hardware_cursors = true
			}

			# Si Xwayland ou Chromium rendent du noir, la variable qu'on ajoute
			# classiquement est « env = GBM_BACKEND,nvidia-drm ». Elle n'est pas mise
			# d'office : selon la version du pilote, elle casse Firefox et Electron.
		EOF
		ok "gpu.conf → NVIDIA"
		pkg_installed nvidia-driver || warn "GPU NVIDIA détecté, mais nvidia-driver n'est pas installé — ce dépôt ne l'installe pas pour toi."
		warn "Le chemin NVIDIA n'a jamais tourné sur cette machine (Radeon) : à vérifier au premier démarrage."
		;;
	amd|intel)
		cat > "$GPU_CONF" <<-EOF
			# Généré par scripts/04-dotfiles.sh — ne pas versionner (voir .gitignore).
			# GPU $GPU détecté : le pilote libre (mesa) est chargé par le noyau et ne
			# demande aucune variable. Fichier volontairement sans réglage.
		EOF
		ok "gpu.conf → $GPU (aucun réglage nécessaire)"
		;;
	*)
		cat > "$GPU_CONF" <<-EOF
			# Généré par scripts/04-dotfiles.sh — ne pas versionner (voir .gitignore).
			# GPU non reconnu : aucun réglage appliqué.
		EOF
		warn "GPU non reconnu (/sys/class/drm muet) — gpu.conf laissé sans réglage."
		;;
esac

# --- Fichiers de surcharge personnels -----------------------------------------
# Rupture assumée avec plugins.conf et gpu.conf, réécrits à chaque passage :
# ceux-ci contiennent le travail de l'utilisateur. On les crée une fois, puis
# plus jamais — les régénérer effacerait précisément ce qu'ils protègent.
#
# Ils sont créés même sans réglage dedans, parce que leur absence coûte cher :
# mako refuse de démarrer si son include est introuvable, et un @import mort fait
# tomber toute la feuille de style de waybar.
creer_si_absent() {
	local chemin="$1"
	local nom="${chemin#"$CONFIG_SRC"/}"

	# stdin (le heredoc de l'appelant) est volontairement laissé non lu :
	# rien ne doit écraser un fichier déjà là.
	if [[ -e "$chemin" ]]; then
		ok "$nom (déjà là — laissé intact)"
		return
	fi

	cat > "$chemin"
	ok "$nom créé"
}

creer_si_absent "$CONFIG_SRC/hypr/local.conf" <<-'EOF'
	# Tes réglages Hyprland. Ignoré par git : « git pull » n'y touchera jamais, et
	# ils ne partiront jamais dans une pull request par accident.
	#
	# Sourcé en dernier par hyprland.conf : ce que tu écris ici gagne.
	#
	#     input {
	#         kb_layout = us
	#     }
	#
	# Les « bind » font exception : ils s'ajoutent au lieu de remplacer. Pour
	# reprendre un raccourci déjà pris, libère-le d'abord :
	#
	#     unbind = SUPER, Return
	#     bind = SUPER, Return, exec, alacritty
EOF

creer_si_absent "$CONFIG_SRC/waybar/local.jsonc" <<-'EOF'
	// Tes réglages waybar. Ignoré par git.
	//
	// config.jsonc inclut ce fichier AVANT defaults.jsonc, et waybar garde la
	// première valeur rencontrée : ce que tu mets ici gagne. Les objets fusionnent
	// clé par clé — redéfinir « "clock": {"format": "…"} » ne jette pas le reste
	// du bloc clock.
	//
	// Garde au moins les accolades : un fichier vide n'est pas du JSON, et waybar
	// refuse alors de démarrer.
	{
	}
EOF

creer_si_absent "$CONFIG_SRC/waybar/local.css" <<-'EOF'
	/* Tes surcharges de style waybar. Ignoré par git.
	   Importé en fin de style.css : à spécificité égale, la dernière règle gagne.
	   Ne supprime pas ce fichier : un @import qui ne trouve rien fait tomber TOUTE
	   la feuille, et waybar s'affiche alors sans thème. */
EOF

creer_si_absent "$CONFIG_SRC/mako/local" <<-'EOF'
	# Tes réglages mako. Ignoré par git.
	# Inclus en dernier par « config » : la dernière valeur écrite gagne, y compris
	# pour les blocs de critères ([urgency=critical]…).
	# Ne supprime pas ce fichier : sans lui, mako refuse de démarrer et tu perds
	# toute notification, sans rien pour te le dire.
EOF

creer_si_absent "$CONFIG_SRC/foot/local.ini" <<-'EOF'
	# Tes réglages foot. Ignoré par git.
	# Inclus en dernier par foot.ini : la dernière valeur écrite gagne. Ce fichier
	# démarre dans la section [main] ; ouvre [colors], [cursor]… au besoin.
	#
	#     font=Fira Code:size=11
	#
	#     [colors]
	#     background=000000
EOF

# --- hy3-rebuild dans le PATH -------------------------------------------------
mkdir -p "$HOME/.local/bin"
ln -sf "$REPO_DIR/bin/hy3-rebuild" "$HOME/.local/bin/hy3-rebuild"
ok "hy3-rebuild → ~/.local/bin/"

if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
	warn "~/.local/bin n'est pas dans ton PATH — ajoute-le à ton ~/.bashrc pour utiliser « hy3-rebuild »."
fi
