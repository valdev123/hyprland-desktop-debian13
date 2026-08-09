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

step "[4/7] Dotfiles"

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

# Un dossier retiré de config/ (foot, remplacé par alacritty) laisse un lien mort
# dans ~/.config. On ne touche qu'à ceux-là : cassés ET pointant dans le dépôt.
for dst in "$CONFIG_DST"/*; do
	[[ -L "$dst" && ! -e "$dst" ]] || continue
	[[ "$(readlink "$dst")" == "$CONFIG_SRC"/* ]] || continue
	rm "$dst"
	warn "$(basename "$dst") : lien mort vers le dépôt, retiré."
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

		# Sans modeset=1, le pilote propriétaire ne fournit pas de KMS : Hyprland
		# ne trouve aucune sortie DRM et refuse simplement de démarrer.
		MODESET="$(cat /sys/module/nvidia_drm/parameters/modeset 2>/dev/null || true)"
		case "$MODESET" in
			Y|1) ok "nvidia_drm.modeset actif" ;;
			"")  warn "Module nvidia_drm non chargé — impossible de vérifier modeset." ;;
			*)   warn "nvidia_drm.modeset = $MODESET : Hyprland ne démarrera pas."
			     warn "Corrige-le : ajoute « options nvidia-drm modeset=1 » dans /etc/modprobe.d/, puis « sudo update-initramfs -u »." ;;
		esac

		warn "Branche NVIDIA : le fichier produit est vérifié, le comportement d'Hyprland sur GPU NVIDIA ne l'est pas."
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

# --- Clavier, résolu pour cette machine ---------------------------------------
# Une rangée de bureaux ne se versionne pas : les noms de touches XKB changent
# avec la disposition (sur AZERTY les chiffres demandent Shift).
KEYBOARD_CONF="$CONFIG_SRC/hypr/keyboard.conf"
read -r KB_LAYOUT KB_VARIANT <<<"$(detect_keyboard)"

# D'une disposition multiple (« fr,us »), seule la première est active au démarrage.
case "${KB_LAYOUT%%,*}" in
	fr|be)
		WS_KEYS=(ampersand eacute quotedbl apostrophe parenleft minus egrave underscore ccedilla)
		# i3 place « focus right » sur la touche à droite du L : c'est M en AZERTY.
		DIR_RIGHT="M"
		;;
	*)
		WS_KEYS=(1 2 3 4 5 6 7 8 9)
		DIR_RIGHT="semicolon"
		;;
esac

{
	cat <<-EOF
		# Généré par scripts/04-dotfiles.sh — ne pas versionner (voir .gitignore).
		# Disposition détectée : ${KB_LAYOUT}${KB_VARIANT:+ ($KB_VARIANT)}.
		# Sourcé après binds.conf, dont il réutilise \$mod.

		input {
		    kb_layout = $KB_LAYOUT
		    kb_variant = $KB_VARIANT
		}

		# --- Focus et déplacement -------------------------------------------------
		bind = \$mod, J, hy3:movefocus, l
		bind = \$mod, K, hy3:movefocus, d
		bind = \$mod, L, hy3:movefocus, u
		bind = \$mod, $DIR_RIGHT, hy3:movefocus, r

		bind = \$mod SHIFT, J, hy3:movewindow, l
		bind = \$mod SHIFT, K, hy3:movewindow, d
		bind = \$mod SHIFT, L, hy3:movewindow, u
		bind = \$mod SHIFT, $DIR_RIGHT, hy3:movewindow, r

		# --- Bureaux --------------------------------------------------------------
	EOF

	for i in "${!WS_KEYS[@]}"; do
		printf 'bind = $mod, %s, workspace, %d\n' "${WS_KEYS[$i]}" "$((i + 1))"
	done
	printf '\n'
	# hy3:movetoworkspace conserve le groupe d'onglets, contrairement au dispatcher standard.
	for i in "${!WS_KEYS[@]}"; do
		printf 'bind = $mod SHIFT, %s, hy3:movetoworkspace, %d\n' "${WS_KEYS[$i]}" "$((i + 1))"
	done
	printf '\n# --- Onglets 1 à 5 du groupe --------------------------------------------------\n'
	for i in 0 1 2 3 4; do
		printf 'bind = $mod ALT, %s, hy3:focustab, %d\n' "${WS_KEYS[$i]}" "$((i + 1))"
	done

	cat <<-EOF

		# --- Mode redimensionnement -----------------------------------------------
		submap = resize
		binde = , J, resizeactive, -40 0
		binde = , K, resizeactive, 0 40
		binde = , L, resizeactive, 0 -40
		binde = , $DIR_RIGHT, resizeactive, 40 0
		submap = reset
	EOF
} > "$KEYBOARD_CONF"
ok "keyboard.conf → $KB_LAYOUT${KB_VARIANT:+ ($KB_VARIANT)}, bureaux sur ${WS_KEYS[0]}…${WS_KEYS[8]}"

# --- Portable ou tour, résolu pour cette machine ------------------------------
# hypridle n'a pas de conditionnel : la suspension ne peut pas vivre dans le
# fichier versionné, qui sert les deux cas.
HYPRIDLE_LOCAL="$CONFIG_SRC/hypr/hypridle-local.conf"
WAYBAR_MACHINE="$CONFIG_SRC/waybar/machine.jsonc"

if is_laptop; then
	cat > "$HYPRIDLE_LOCAL" <<-'EOF'
		# Généré par scripts/04-dotfiles.sh — ne pas versionner (voir .gitignore).
		# Portable détecté : suspension après 30 min d'inactivité.

		listener {
		    timeout = 1800
		    on-timeout = systemctl suspend
		}
	EOF

	cat > "$WAYBAR_MACHINE" <<-'EOF'
		// Généré par scripts/04-dotfiles.sh — ne pas versionner (voir .gitignore).
		// Portable détecté : la barre reprend celle par défaut, batterie en plus.
		{
		  "modules-right": ["pulseaudio", "network", "battery", "cpu", "memory", "tray"],

		  "battery": {
		    "states": { "warning": 30, "critical": 15 },
		    "format": "BAT {capacity}%",
		    "format-charging": "CHR {capacity}%",
		    "format-plugged": "SECTEUR {capacity}%",
		    "tooltip-format": "{timeTo}"
		  }
		}
	EOF
	ok "portable détecté → suspension auto + module batterie"
else
	cat > "$HYPRIDLE_LOCAL" <<-'EOF'
		# Généré par scripts/04-dotfiles.sh — ne pas versionner (voir .gitignore).
		# Aucune batterie : pas de suspension automatique.
	EOF

	# Un objet vide, pas un fichier vide : waybar refuse de démarrer sur du JSON
	# invalide, y compris venu d'un include.
	cat > "$WAYBAR_MACHINE" <<-'EOF'
		// Généré par scripts/04-dotfiles.sh — ne pas versionner (voir .gitignore).
		// Aucune batterie détectée : rien à ajouter à la barre.
		{
		}
	EOF
	ok "tour détectée → ni suspension auto, ni module batterie"
fi

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

creer_si_absent "$CONFIG_SRC/hypr/monitors.conf" <<-'EOF'
	# Disposition de tes écrans. Ignoré par git : les noms de sortie (DP-1, eDP-1…)
	# n'ont de sens que sur la machine où ils ont été lus.
	#
	# Sourcé après la règle générique de hyprland.conf, donc il la surcharge.
	# « hypr-monitors save » remplit ce fichier à partir de l'affichage en cours.
	#
	#     monitor = DP-1, 2560x1440@144, 0x0, 1
	#     monitor = HDMI-A-1, 1920x1080@60, 2560x0, 1
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

creer_si_absent "$CONFIG_SRC/alacritty/local.toml" <<-'EOF'
	# Tes réglages Alacritty. Ignoré par git.
	# Importé après defaults.toml par alacritty.toml, qui ne contient lui-même
	# aucun réglage : ce que tu écris ici gagne.
	#
	#     [font]
	#     size = 13.0
EOF

creer_si_absent "$CONFIG_SRC/tmux/local.conf" <<-'EOF'
	# Tes réglages tmux. Ignoré par git.
	# Sourcé en dernier par tmux.conf : la dernière valeur écrite gagne.
	#
	#     set -g prefix C-a
EOF

creer_si_absent "$CONFIG_SRC/zsh/local.zsh" <<-'EOF'
	# Tes réglages zsh. Ignoré par git.
	# Sourcé en dernier par .zshrc : la dernière valeur écrite gagne.
	#
	#     alias gs='git status'
EOF

# --- Le pointeur que zsh impose dans $HOME ------------------------------------
# zsh ne lit que ~/.zshrc ; ~/.zshenv est le seul fichier par lequel le renvoyer
# vers ~/.config/zsh, donc le seul qui ne puisse pas vivre dans le dépôt.
ZSHENV="$HOME/.zshenv"
LIGNE_ZDOTDIR='export ZDOTDIR="$HOME/.config/zsh"'

if [[ -f "$ZSHENV" ]] && grep -qxF "$LIGNE_ZDOTDIR" "$ZSHENV"; then
	ok "~/.zshenv (déjà en place)"
else
	if [[ -e "$ZSHENV" ]]; then
		cp "$ZSHENV" "$ZSHENV.bak"
		warn "~/.zshenv existait → sauvegardé en ~/.zshenv.bak"
	fi
	printf '%s\n' \
		'# Écrit par scripts/04-dotfiles.sh. Renvoie zsh vers ~/.config/zsh,' \
		'# lié au dépôt — le reste de la config est là-bas.' \
		"$LIGNE_ZDOTDIR" > "$ZSHENV"
	ok "~/.zshenv → ZDOTDIR=~/.config/zsh"
fi

# --- Commandes du dépôt dans le PATH ------------------------------------------
mkdir -p "$HOME/.local/bin"
for cmd in hy3-rebuild hypr-monitors; do
	ln -sf "$REPO_DIR/bin/$cmd" "$HOME/.local/bin/$cmd"
	ok "$cmd → ~/.local/bin/"
done

if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
	warn "~/.local/bin n'est pas dans ton PATH — le .zshrc du dépôt l'ajoute, ouvre un nouveau terminal pour utiliser « hy3-rebuild »."
fi
