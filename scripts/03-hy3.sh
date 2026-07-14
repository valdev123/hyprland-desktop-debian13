#!/usr/bin/env bash
# Compile et installe le plugin hy3, accordé à la version d'Hyprland installée.
#
# POURQUOI CE SCRIPT NE CODE PAS LE TAG EN DUR
# --------------------------------------------
# On lit souvent « git checkout hl<version d'Hyprland> ». C'est faux : hy3 ne
# publie pas un tag par patch d'Hyprland. Au 14/07/2026, Debian livre Hyprland
# 0.55.2 alors que le tag hy3 le plus récent est hl0.55.0 — « hl0.55.2 »
# n'existe pas et un checkout dessus échoue. On résout donc le tag à l'exécution :
# le plus haut tag hy3 inférieur ou égal à la version d'Hyprland.
#
# POURQUOI ÇA CHARGE QUAND MÊME
# -----------------------------
# Au chargement, hy3 compare le hash du compositeur en cours d'exécution avec le
# hash compilé dans le plugin (main.cpp : COMPOSITOR_HASH vs CLIENT_HASH). Ce
# second hash vient des *headers* de hyprland-dev, pas du nom du tag. Comme on
# compile contre les headers de l'Hyprland réellement installé, les deux hash
# coïncident. Le nom du tag n'intervient jamais dans le contrôle.

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

HY3_REPO="https://github.com/outfoxxed/hy3"
SRC_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/hy3-src"
PLUGIN_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/hyprland/plugins"
PLUGIN_SO="$PLUGIN_DIR/libhy3.so"

step "[3/4] Plugin hy3"

pkg_installed hyprland     || die "hyprland n'est pas installé. Lance d'abord scripts/02-packages.sh."
pkg_installed hyprland-dev || die "hyprland-dev n'est pas installé : impossible de compiler un plugin sans les headers."

HYPR_VER="$(pkg_upstream_version hyprland)"
log "Hyprland installé : $HYPR_VER"

# --- Résolution du tag hy3 ----------------------------------------------------
if [[ -n "${HY3_TAG:-}" ]]; then
	TAG="$HY3_TAG"
	warn "Tag imposé par HY3_TAG : $TAG"
else
	log "Recherche des tags hy3 compatibles"
	mapfile -t TAGS < <(
		git ls-remote --tags --refs "$HY3_REPO" 2>/dev/null \
			| sed 's#.*refs/tags/##' \
			| grep -E '^hl[0-9]' \
			| sed 's/^hl//' \
			| sort -V
	)
	[[ ${#TAGS[@]} -gt 0 ]] || die "Aucun tag récupéré depuis $HY3_REPO (réseau ?)."

	# Le plus haut tag <= version d'Hyprland.
	BEST=""
	for v in "${TAGS[@]}"; do
		if [[ "$(printf '%s\n%s\n' "$v" "$HYPR_VER" | sort -V | head -n1)" == "$v" ]]; then
			BEST="$v"
		fi
	done
	[[ -n "$BEST" ]] || die "Aucun tag hy3 n'est <= Hyprland $HYPR_VER. Hyprland est probablement trop récent pour hy3."

	TAG="hl$BEST"

	# Un écart de version mineure signale une vraie incompatibilité d'API :
	# on prévient franchement plutôt que de laisser la compilation échouer
	# sur des erreurs C++ incompréhensibles.
	if [[ "${BEST%.*}" != "${HYPR_VER%.*}" ]]; then
		warn "hy3 $TAG ne vise pas la série ${HYPR_VER%.*}.x d'Hyprland."
		warn "La compilation peut échouer. Suis https://github.com/outfoxxed/hy3/releases"
	fi
fi
ok "Tag retenu : $TAG (pour Hyprland $HYPR_VER)"

# --- Récupération des sources -------------------------------------------------
if [[ -d "$SRC_DIR/.git" ]]; then
	log "Mise à jour des sources dans $SRC_DIR"
	git -C "$SRC_DIR" fetch --tags --quiet --force
else
	log "Clonage dans $SRC_DIR"
	mkdir -p "$(dirname "$SRC_DIR")"
	git clone --quiet "$HY3_REPO" "$SRC_DIR"
fi

git -C "$SRC_DIR" checkout --quiet --detach "$TAG" \
	|| die "Le tag $TAG n'existe pas dans hy3. Vérifie $HY3_REPO/releases"

# --- Compilation --------------------------------------------------------------
log "Compilation (cmake + ninja)"
rm -rf "$SRC_DIR/build"
if ! cmake -S "$SRC_DIR" -B "$SRC_DIR/build" -G Ninja -DCMAKE_BUILD_TYPE=Release >/dev/null; then
	die "Échec de la configuration cmake. Vérifie que hyprland-dev et libpango1.0-dev sont installés."
fi
cmake --build "$SRC_DIR/build" --parallel "$(nproc)" \
	|| die "Échec de la compilation de hy3 : l'API d'Hyprland $HYPR_VER a probablement changé depuis $TAG."

BUILT="$SRC_DIR/build/libhy3.so"
[[ -f "$BUILT" ]] || die "Compilation terminée mais $BUILT est introuvable."

# --- Installation -------------------------------------------------------------
mkdir -p "$PLUGIN_DIR"
install -m 0644 "$BUILT" "$PLUGIN_SO"

ok "Plugin installé : $PLUGIN_SO"
printf '\n%s  Rappel :%s après chaque mise à jour d'\''Hyprland, relance « hy3-rebuild »,\n' "$C_YELLOW" "$C_RESET"
printf '  sinon Hyprland refusera de charger le plugin (hash différent).\n'
