# Ce que l'installation pose sur la machine

Inventaire de tout ce que `./install.sh` ajoute au système : paquets APT, code
compilé, commandes déposées dans le `PATH`.

Le README dit *pourquoi* c'est là, les scripts disent *comment*. Ce fichier
répond à la seule question qu'aucun des deux ne traite d'un coup d'œil : **qu'y
a-t-il sur ma machine à cause de ce dépôt ?** — pour désinstaller, pour auditer,
ou pour vérifier qu'un outil dont la config est ici est bien installé avec elle.

**Tout outil configuré dans `config/` doit figurer ici et être installé par un
script.** Une config qui suppose un binaire absent est une session cassée au
premier démarrage.

---

## Étape 1 — dépôt

`scripts/01-backports.sh` active `trixie-backports` (aucun paquet installé).

## Étape 2 — Hyprland et sa famille

Depuis `trixie-backports` : Hyprland n'existe pas dans `trixie/main`.

| Paquet | Rôle |
|---|---|
| `hyprland` | le compositeur |
| `hyprland-dev` | headers + `hyprland.pc`, indispensables pour compiler hy3 |
| `hyprland-qtutils` | boîtes de dialogue Qt d'Hyprland |
| `xdg-desktop-portal-hyprland` | partage d'écran, sélecteurs de fichiers |
| `hyprlock` | verrouillage d'écran |
| `hypridle` | mise en veille sur inactivité |
| `hyprpaper` | fond d'écran |
| `hyprland-backgrounds` | fournit le `wall0.png` utilisé par `hyprpaper.conf` |
| `hyprpicker` | pipette à couleurs |
| `hyprpolkitagent` | agent d'authentification polkit |

## Étape 2 — écosystème desktop

Depuis `trixie/main`, avec `-t trixie-backports` pour que les bibliothèques
partagées avec Hyprland restent cohérentes.

| Domaine | Paquets |
|---|---|
| Session | `xdg-desktop-portal`, `xdg-desktop-portal-gtk`, `xwayland`, `qt6-wayland` |
| Interface | `waybar` (barre), `wofi` (lanceur), `foot` (terminal), `mako-notifier` (notifications) |
| Outils | `grim` + `slurp` (captures), `wl-clipboard`, `brightnessctl`, `playerctl`, `jq`, `thunar`, `udiskie` (montage auto), `pavucontrol`, `blueman` |
| Audio | `pipewire`, `pipewire-pulse`, `wireplumber` |
| Réseau | `network-manager`, `network-manager-gnome` (`nm-applet`) |
| Polices et icônes | `fonts-jetbrains-mono`, `fonts-font-awesome`, `fonts-noto-color-emoji`, `papirus-icon-theme` |

## Étape 2 — chaîne de compilation de hy3

`git`, `cmake`, `ninja-build`, `g++`, `pkg-config`, `libpango1.0-dev`.

Le dernier est le piège classique : `hyprland-dev` ne le tire pas, et le
`CMakeLists` de hy3 exige les modules pkg-config `pango` et `pangocairo`.

## Étape 3 — hy3

Aucun paquet : le plugin est compilé depuis les sources.

| Chemin | Contenu |
|---|---|
| `~/.local/share/hy3-src/` | clone de `github.com/outfoxxed/hy3` |
| `~/.local/share/hyprland/plugins/libhy3.so` | le plugin chargé par Hyprland |

## Étape 4 — dotfiles et commandes

Chaque dossier de `config/` est lié dans `~/.config/`. Deux commandes sont liées
dans `~/.local/bin/` :

| Commande | Rôle |
|---|---|
| `hy3-rebuild` | recompile hy3 après une mise à jour d'Hyprland |
| `hypr-monitors` | lit la disposition des écrans, l'écrit dans `monitors.conf` |

## Étape 5 — plomberie GNOME

Installée avec `--no-install-recommends` : sans ce garde-fou, le bureau GNOME
complet entre par la porte des recommandations.

| Paquet | Rôle |
|---|---|
| `gnome-keyring` | trousseau de mots de passe (API Secret Service) |
| `libpam-gnome-keyring` | déverrouille le trousseau via PAM |
| `gsettings-desktop-schemas` | schémas des réglages GTK |
| `dconf-cli` | stockage de ces réglages |
| `libglib2.0-bin` | fournit la commande `gsettings` |
| `nautilus` | gestionnaire de fichiers GTK |
| `librsvg2-common` | icônes SVG de nautilus |
| `adwaita-icon-theme` | thème d'icônes par défaut |

Aucun GNOME Shell, aucun `gdm3`, aucun `xdg-desktop-portal-gnome`.

## Étape 6 — écran de connexion

`greetd` et `tuigreet`.

---

## Ce que le dépôt n'installe pas

- **Aucun pilote GPU.** Sur NVIDIA, `04-dotfiles.sh` détecte la carte et écrit
  `gpu.conf`, mais prévient que `nvidia-driver` est à ta charge.
- **Aucun navigateur, aucune application de travail.**
- `wpctl` (wireplumber), `hyprctl` (hyprland) et `loginctl` (systemd) sont
  utilisés par les raccourcis : ils viennent de paquets déjà listés.

## Désinstaller

Il n'y a pas de script pour ça. Les paquets se retirent avec
`sudo apt purge --autoremove <liste>` ; le reste tient dans quatre chemins :
`~/.config/{hypr,waybar,wofi,foot,mako}` (des liens), `~/.local/share/hy3-src`,
`~/.local/share/hyprland/plugins`, `~/.local/bin/{hy3-rebuild,hypr-monitors}`.
Côté système, `/etc/greetd/config.toml` et `/etc/pam.d/greetd` ont chacun un
`.bak`.
