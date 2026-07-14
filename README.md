# hyprland-debian13

Installation d'**Hyprland + le plugin hy3** sur **Debian 13 (trixie)**, avec un
bureau utilisable dès le premier démarrage et des dotfiles versionnés.

```bash
git clone <ton-repo> ~/hyprland-debian13
cd ~/hyprland-debian13
./install.sh
```

Puis, depuis un TTY : `Hyprland`.

---

## Ce que fait le script

| Étape | Script | Contenu |
|---|---|---|
| 1 | `scripts/01-backports.sh` | Active `trixie-backports` |
| 2 | `scripts/02-packages.sh` | Hyprland + hyprlock/hypridle/hyprpaper/portail, puis waybar, foot, wofi, mako, pipewire, NetworkManager… |
| 3 | `scripts/03-hy3.sh` | Compile hy3 contre l'Hyprland installé, pose `libhy3.so` |
| 4 | `scripts/04-dotfiles.sh` | Lie `config/` à `~/.config/` (sauvegarde l'existant) |
| 5 | `scripts/05-gnome.sh` | Plomberie GNOME : trousseau, thème GTK sombre, portail |
| 6 | `scripts/06-greetd.sh` | Écran de connexion greetd + tuigreet |

Le script est **idempotent** : le relancer ne casse rien. On peut n'en rejouer
qu'une partie : `./install.sh hy3`, `./install.sh dotfiles`, `./install.sh gnome`,
`./install.sh greetd`.

### Étape 5 — la « plomberie GNOME », qui n'est pas GNOME

Un bureau se compose de trois couches indépendantes, et il est facile de les
confondre :

1. **L'écran de connexion** (étape 6) — choisit ta session au démarrage.
2. **La plomberie** (étape 5) — des services sans interface : trousseau de mots
   de passe (`gnome-keyring`), réglages GTK (`gsettings` / `dconf` : thème
   sombre, police, curseur), portails (sélecteur de fichiers, partage d'écran).
3. **Le bureau** — GNOME Shell, KDE, **ou Hyprland**. Un seul à la fois.

La couche 2 vient historiquement de GNOME mais **n'est pas** GNOME : Hyprland,
Sway et KDE s'en servent tous. C'est précisément ce qui manque à une session
Hyprland nue — sans elle, les applis GTK restent en thème clair et beaucoup
d'applications redemandent tes mots de passe à chaque lancement. Aucun GNOME
Shell n'est installé, rien ne concurrence Hyprland.

### Étape 6 — l'écran de connexion

`greetd` + `tuigreet` remplacent la connexion en TTY par un menu de session. Les
sessions proposées sont lues dans `/usr/share/wayland-sessions/`, où le paquet
Debian d'Hyprland dépose `hyprland.desktop` — **Sway y figure aussi** s'il est
installé, donc les deux apparaissent sans rien déclarer.

greetd tourne sur le **TTY 7**, délibérément : les TTY 1 à 6 gardent leur invite
texte. Si une session graphique refuse de démarrer, `Ctrl`+`Alt`+`F2` donne
toujours un shell. Pour revenir en arrière : `sudo systemctl disable greetd`.

Le trousseau est branché sur PAM (`/etc/pam.d/greetd`) pour se déverrouiller avec
ton mot de passe de session, au lieu d'en réclamer un second. Les deux lignes
ajoutées sont `optional` : si le module échoue, PAM les ignore — elles ne peuvent
pas te verrouiller dehors. L'original est sauvegardé en `.bak`.

---

## Les deux choses à savoir

### 1. Hyprland n'est pas dans Debian 13 stable

Il n'existe **aucun** paquet `hyprland` dans `trixie/main` — beaucoup de guides
laissent croire le contraire. Le seul Hyprland empaqueté par Debian vit dans
**`trixie-backports`** (0.55.2 au 14/07/2026), avec tout son écosystème :
`hyprlock`, `hypridle`, `hyprpaper`, `hyprpolkitagent`,
`xdg-desktop-portal-hyprland`, et même quelques plugins officiels.

Mais **pas hy3** : celui-là, il faut le compiler. D'où l'étape 3.

### 2. Le tag hy3 ne se code pas en dur

On lit partout `git checkout hl<version d'Hyprland>`. **C'est faux.** hy3 ne
publie pas un tag par version d'Hyprland : Debian livre Hyprland **0.55.2**
alors que le dernier tag hy3 est **`hl0.55.0`**. `hl0.55.2` n'existe pas, et un
`checkout` dessus échoue.

`scripts/03-hy3.sh` résout donc le tag **à l'exécution** : il prend le plus haut
tag hy3 inférieur ou égal à la version d'Hyprland installée.

**Et ça charge quand même**, parce que le contrôle de compatibilité de hy3 ne
regarde pas le nom du tag. Au chargement, le plugin compare le hash du
compositeur en cours d'exécution avec un hash compilé dans le `.so`, qui provient
des **headers de `hyprland-dev`** (`src/main.cpp` : `COMPOSITOR_HASH` vs
`CLIENT_HASH`). Comme on compile contre les headers de l'Hyprland réellement
installé, les deux coïncident. Le tag ne sert qu'à choisir une version du *code
source* de hy3 compatible avec l'API.

Conséquence directe, et c'est la seule vraie contrainte à retenir :

> **Après chaque mise à jour d'Hyprland, relance `hy3-rebuild`.**
> Sinon les hash divergent et Hyprland refuse de charger le plugin — notification
> rouge « *hy3 was compiled for a different version of hyprland* », et tu
> retombes sur la disposition `dwindle`.

```bash
sudo apt upgrade      # Hyprland passe de 0.55.2 à 0.56.x
hy3-rebuild           # recompile, réinstalle, recharge
```

---

## Raccourcis

`Super` = touche Windows. Clavier **AZERTY** (`kb_layout = fr`).

| Touches | Action |
|---|---|
| `Super` + `Q` / `R` / `E` | terminal / lanceur / fichiers |
| `Super` + `C` | fermer la fenêtre ou l'onglet |
| `Super` + `M` | quitter Hyprland |
| `Super` + `H` / `V` | découper horizontalement / verticalement *(hy3)* |
| `Super` + `Entrée` | regrouper en onglets *(hy3)* |
| `Super` + `S` | basculer groupe ↔ onglets *(hy3)* |
| `Super` + `Tab` | onglet suivant *(hy3)* |
| `Super` + `A` / `Shift`+`A` | remonter / redescendre dans l'arbre *(hy3)* |
| `Super` + flèches | changer de fenêtre |
| `Super` + `Shift` + flèches | déplacer la fenêtre |
| `Super` + `Ctrl` + flèches | redimensionner |
| `Super` + `&` … `ç` | bureaux 1 à 9 |
| `Super` + `L` | verrouiller |
| `Impr. écran` | capture d'une zone → presse-papier |

Tout est dans `config/hypr/binds.conf`, modifiable à chaud (`hyprctl reload`).

---

## Structure

```
install.sh              orchestrateur
bin/hy3-rebuild         recompile hy3 après une mise à jour d'Hyprland
lib/common.sh           logs, garde-fous, helpers apt
scripts/                les 4 étapes
config/                 dotfiles, liés dans ~/.config
  hypr/    hyprland.conf, binds.conf, hy3.conf, hyprlock, hypridle, hyprpaper
  waybar/  config.jsonc, style.css
  foot/    mako/    wofi/
```

`config/hypr/plugins.conf` est **généré** (chemin absolu du `.so`, propre à la
machine) et ignoré par git.

---

## Dépannage

**Hyprland démarre mais les fenêtres ne se découpent pas comme prévu**
Le plugin n'est pas chargé — Hyprland est retombé sur `dwindle`.

```bash
hyprctl plugin list          # hy3 doit apparaître
hy3-rebuild
```

**« hy3 was compiled for a different version of hyprland »**
Hyprland a été mis à jour sans recompilation du plugin : `hy3-rebuild`.

**La compilation de hy3 échoue**
Soit `libpango1.0-dev` manque (hy3 exige `pango` et `pangocairo` en pkg-config,
et `hyprland-dev` ne les tire pas), soit l'API d'Hyprland a bougé et hy3 n'a pas
encore de tag pour cette version. Regarde
[les releases hy3](https://github.com/outfoxxed/hy3/releases). On peut forcer un
tag :

```bash
HY3_TAG=hl0.55.0 ./install.sh hy3
```

**Écran noir au lancement**
Vérifie que le GPU est bien pris en charge : `lspci -k | grep -A3 VGA` doit
montrer `amdgpu`.

**Retrouver ses anciennes configs**
Elles sont dans `~/.config-backup-<date>/`, jamais supprimées.

---

## Notes matérielles (cette machine)

- **GPU Radeon RX 6950 XT** : pilote libre `amdgpu`, rien à configurer.
- **Wifi Broadcom BCM4360** : nécessite `broadcom-sta-dkms` et un **Secure Boot
  désactivé** (module non signé). Sans rapport avec Hyprland, mais c'est ce qui
  fournit le réseau.

## Liens

- [Wiki Hyprland](https://wiki.hypr.land)
- [hy3](https://github.com/outfoxxed/hy3) — [releases](https://github.com/outfoxxed/hy3/releases)
- [Debian backports](https://backports.debian.org/Instructions/)
