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

# --- hy3-rebuild dans le PATH -------------------------------------------------
mkdir -p "$HOME/.local/bin"
ln -sf "$REPO_DIR/bin/hy3-rebuild" "$HOME/.local/bin/hy3-rebuild"
ok "hy3-rebuild → ~/.local/bin/"

if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
	warn "~/.local/bin n'est pas dans ton PATH — ajoute-le à ton ~/.bashrc pour utiliser « hy3-rebuild »."
fi
