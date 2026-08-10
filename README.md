# hyprland-desktop-debian13

Un **environnement de bureau complet** sous **Hyprland**, sur **Debian 13
(trixie)** : le compositeur pavé, ses raccourcis calqués sur i3, et ce qu'un
bureau exige pour être utilisable — barre, lanceur, terminal, notifications,
verrouillage, audio, réseau, trousseau, écran de connexion.

```bash
git clone <ton-repo> ~/hyprland-desktop-debian13
cd ~/hyprland-desktop-debian13
./install.sh
```

Puis, depuis un TTY : `Hyprland`.

Les pilotes GPU ne sont pas installés, délibérément.

---

## Les 7 étapes

| Étape | Script | Contenu |
|---|---|---|
| 1 | `01-backports.sh` | Active `trixie-backports` |
| 2 | `02-packages.sh` | Hyprland et son écosystème, puis waybar, alacritty, wofi, mako, zsh, tmux, pipewire, NetworkManager… ; passe le shell de connexion à zsh |
| 3 | `03-hy3.sh` | Compile hy3 contre l'Hyprland installé |
| 4 | `04-dotfiles.sh` | Lie `config/` à `~/.config/` (sauvegarde l'existant) |
| 5 | `05-gnome.sh` | Plomberie GNOME : trousseau, thème GTK sombre, portail |
| 6 | `06-greetd.sh` | Écran de connexion greetd + tuigreet |
| 7 | `07-apps.sh` | VS Code, Google Chrome, Zed — les trois qui échappent à Debian |

**Idempotent** : le relancer ne casse rien. Cibles partielles : `packages`,
`hy3`, `dotfiles`, `gnome`, `greetd`, `apps` — `packages` rejoue l'étape 1 avant
la 2, sans les backports apt ne voit aucun paquet Hyprland.

Inventaire complet de ce qui atterrit sur la machine, paquet par paquet et chemin
par chemin : [PAQUETS.md](PAQUETS.md).

---

## Ce qu'il faut savoir

### Hyprland n'est pas dans Debian 13 stable

Il n'existe **aucun** paquet dans `trixie/main`, contrairement à ce que laissent
croire beaucoup de guides : le seul Hyprland empaqueté vit dans
**`trixie-backports`** (0.55.2), avec `hyprlock`, `hypridle`, `hyprpaper`,
`hyprpolkitagent` et le portail. Mais pas hy3 — d'où l'étape 3.

### Le tag hy3 ne se code pas en dur

On lit partout `git checkout hl<version d'Hyprland>`. **C'est faux** : hy3 ne
publie pas un tag par version d'Hyprland — Debian livre **0.55.2** quand le
dernier tag hy3 est **`hl0.55.0`**, sur lequel un `checkout` échoue.
`03-hy3.sh` résout donc le tag **à l'exécution** : le plus haut tag inférieur ou
égal à la version installée.

Et ça charge quand même, parce que le contrôle de compatibilité ne regarde pas le
nom du tag : hy3 compare le **hash du compositeur en cours** avec celui compilé
dans le `.so`, issu des headers de `hyprland-dev`. Comme on compile contre
l'Hyprland réellement installé, les deux coïncident. D'où la seule vraie
contrainte à retenir :

> **Après chaque mise à jour d'Hyprland, relance `hy3-rebuild`.** Sinon les hash
> divergent, Hyprland refuse le plugin et tu retombes sur `dwindle`.

### L'étape 5 n'installe pas GNOME

Elle pose une couche de services **sans interface** — trousseau
(`gnome-keyring`), réglages GTK (thème sombre, police, curseur), portails
(sélecteur de fichiers, partage d'écran) — que Sway et KDE utilisent tout autant.
C'est ce qui manque à une session Hyprland nue : sans elle, les applis GTK
restent en thème clair et les mots de passe sont redemandés à chaque lancement.
Aucun GNOME Shell n'est installé, rien ne concurrence Hyprland.

### greetd tourne sur le TTY 7

Délibérément : les TTY 1 à 6 gardent leur invite texte, donc `Ctrl`+`Alt`+`F2`
donne toujours un shell si la session graphique refuse de démarrer. Les sessions
proposées sont lues dans `/usr/share/wayland-sessions/` — Sway y figure aussi
s'il est installé. Pour revenir en arrière : `sudo systemctl disable greetd`.

---

## Raccourcis

`Super` = touche Windows. La disposition du clavier est **détectée**, pas
imposée : les touches ci-dessous sont celles d'un AZERTY, les lignes marquées ¹
changent ailleurs.

| Touches | Action |
|---|---|
| `Super` + `Entrée` / `D` / `N` | terminal / lanceur / fichiers |
| `Super` + `Shift` + `Q` | fermer la fenêtre ou l'onglet |
| `Super` + `Shift` + `E` | menu de session (verrouiller, veille, redémarrer, éteindre, quitter) |
| `Super` + `Shift` + `C` | recharger la config |
| `Super` + `H` / `V` | découper horizontalement / verticalement *(hy3)* |
| `Super` + `E` | basculer le sens de la découpe *(hy3)* |
| `Super` + `W` | regrouper en onglets *(hy3)* |
| `Super` + `S` | basculer onglets ↔ découpe *(hy3)* |
| `Super` + `Tab` | onglet suivant *(hy3)* |
| `Super` + `A` / `Shift`+`A` | remonter / redescendre dans l'arbre *(hy3)* |
| `Super` + `J` `K` `L` `M` ¹ ou flèches | changer de fenêtre |
| `Super` + `Shift` + idem | déplacer la fenêtre |
| `Super` + `R` | mode redimensionnement, `Échap` pour sortir |
| `Super` + `F` | plein écran |
| `Super` + `&` … `ç` ¹ | bureaux 1 à 9 |
| `Super` + `Ctrl` + `L` | verrouiller *(`Super`+`L` sert au focus)* |
| `Impr. écran` | capture d'une zone → presse-papier |

Tout est dans `config/hypr/binds.conf`, modifiable à chaud (`hyprctl reload`) —
sauf les lignes ¹, générées dans `keyboard.conf`.

---

## Structure

```
install.sh              orchestrateur
bin/hy3-rebuild         recompile hy3 après une mise à jour d'Hyprland
bin/hypr-monitors       fige la disposition des écrans dans monitors.conf
bin/hypr-power          menu de session (Super+Shift+E)
lib/common.sh           logs, garde-fous, détection matérielle, helpers apt
scripts/                les 7 étapes
config/                 dotfiles, liés dans ~/.config
  hypr/       hyprland.conf, binds.conf, hy3.conf, hyprlock, hypridle, hyprpaper
  waybar/     config.jsonc (shim), defaults.jsonc, style.css
  alacritty/  alacritty.toml (shim), defaults.toml
  zsh/        .zshrc
  tmux/       mako/    wofi/
```

Alacritty n'ouvre pas un shell mais `tmux new-session` — une session neuve par
fenêtre. C'est réglé côté Alacritty et non dans le `.zshrc`, pour que les
terminaux intégrés de VS Code et Zed gardent un shell nu.

Le shell de connexion est zsh (`chsh` à l'étape 2 ; `sudo chsh -s /bin/bash
$USER` pour revenir). Comme zsh ne lit que `~/.zshrc`, l'étape 4 écrit un
`~/.zshenv` de trois lignes qui pose `ZDOTDIR=~/.config/zsh` : c'est le seul
fichier dont zsh impose l'emplacement, donc le seul qui ne puisse pas vivre dans
le dépôt.

### Tes réglages : les fichiers `local`

Les dotfiles sont déployés par **liens symboliques** : éditer sa config, c'est
éditer le dépôt, et chaque `git pull` deviendrait un conflit. D'où un fichier
`local` par programme, ignoré par git et **lu en dernier** — c'est lui qui gagne :

```
hypr/local.conf      waybar/local.jsonc    waybar/local.css
mako/local           alacritty/local.toml  tmux/local.conf
zsh/local.zsh
```

Trois choses que le code ne peut pas dire :

- **waybar et alacritty sont coupés en deux** (`config.jsonc` et `alacritty.toml`
  ne règlent rien) : dans les deux cas un fichier inclus ne peut pas battre celui
  qui l'inclut, sans ce shim vide aucune surcharge ne serait possible.
- **Ces fichiers sont créés une fois puis jamais régénérés** : ils contiennent ton
  travail.
- **Un `git pull` qui ajoute un nouveau `local` exige `./install.sh dotfiles`**,
  sinon mako, qui refuse de démarrer sur un include introuvable, reste muet.

**wofi est l'exception** : il charge son CSS avec `load_from_data`, donc un
`@import` y serait résolu depuis son répertoire courant et non depuis
`style.css`. Ses 43 lignes cosmétiques s'éditent directement.

---

## Ce qui dépend de la machine

Un réglage propre à une machine ne peut qu'être faux ailleurs — et faux ici le
jour où le matériel change. `04-dotfiles.sh` interroge donc le système et écrit
ce qu'il trouve dans des fichiers non versionnés, régénérés à chaque passage :

| Fichier | Lu dans | Ce qu'il évite |
|---|---|---|
| `hypr/gpu.conf` | `/sys/class/drm` | Des variables NVIDIA sur une carte AMD, où elles cassent le rendu |
| `hypr/keyboard.conf` | `/etc/default/keyboard` | Une rangée de bureaux inatteignable : sur AZERTY, `Super`+`1` envoie `&` |
| `hypr/hypridle-local.conf` | `/sys/class/power_supply` | Une tour qui se suspend, ou un portable qui vide sa batterie |
| `waybar/machine.jsonc` | idem | Un module batterie vide sur une tour |
| `hypr/monitors.conf` | `hypr-monitors save` | Des noms de sortie (`DP-1`, `eDP-1`) qui ne valent que sur une machine |

`monitors.conf` fait exception : il contient un choix, donc il se comporte comme
un fichier `local` et n'est écrit qu'une fois.

Cette machine : **Radeon RX 6950 XT** (pilote libre `amdgpu`, `gpu.conf` sort
vide) et **wifi Broadcom BCM4360**, qui exige `broadcom-sta-dkms` et un **Secure
Boot désactivé**. Le chemin NVIDIA n'a jamais tourné — pour l'exercer sans le
matériel : `HY3_GPU=nvidia`, `HY3_KEYBOARD=us`, `HY3_LAPTOP=1`.

---

## Dépannage

**Les fenêtres ne se découpent pas comme prévu**
Le plugin n'est pas chargé, Hyprland est retombé sur `dwindle` :
`hyprctl plugin list`, puis `hy3-rebuild`.

**« hy3 was compiled for a different version of hyprland »**
Hyprland a été mis à jour sans recompilation : `hy3-rebuild`.

**La compilation de hy3 échoue**
Soit `libpango1.0-dev` manque (hy3 l'exige, `hyprland-dev` ne le tire pas), soit
l'API a bougé et hy3 n'a pas encore de tag pour cette version — voir
[les releases](https://github.com/outfoxxed/hy3/releases). On peut forcer un
tag : `HY3_TAG=hl0.55.0 ./install.sh hy3`.

**Écran noir au lancement**
`lspci -k | grep -A3 VGA` doit montrer `amdgpu`. Sur NVIDIA, vérifie
`~/.config/hypr/gpu.conf` et que `nvidia-driver` est installé — ce dépôt ne
l'installe pas.

**« open terminal failed: not a terminal »**
Un `apt upgrade` a remplacé le binaire tmux pendant qu'un serveur tournait : le
client neuf ne sait plus lui parler, la session est créée mais jamais attachée.
Compare `tmux -V` et `tmux display-message -p '#{version}'`, puis
`tmux kill-server` — les sessions ouvertes sont perdues.

**Retrouver ses anciennes configs**
Dans `~/.config-backup-<date>/`, jamais supprimées.

---

## Liens

- [Wiki Hyprland](https://wiki.hypr.land)
- [hy3](https://github.com/outfoxxed/hy3) — [releases](https://github.com/outfoxxed/hy3/releases)
- [Debian backports](https://backports.debian.org/Instructions/)
