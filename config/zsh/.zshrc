# Shell interactif. Lu ici grâce à ZDOTDIR, posé dans ~/.zshenv par
# scripts/04-dotfiles.sh — zsh, lui, ne cherche que ~/.zshrc.

# Ce que Debian ne fait que pour bash, dans ~/.profile.
path=("$HOME/.local/bin" $path)

ZSH_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
mkdir -p "$ZSH_CACHE"

# --- Historique ---------------------------------------------------------------
HISTFILE="${XDG_STATE_HOME:-$HOME/.local/state}/zsh/history"
mkdir -p "${HISTFILE:h}"
HISTSIZE=50000
SAVEHIST=50000

setopt share_history inc_append_history extended_history
setopt hist_ignore_all_dups hist_ignore_space hist_reduce_blanks

# --- Comportement du shell ----------------------------------------------------
setopt auto_cd auto_pushd pushd_ignore_dups
setopt interactive_comments
unsetopt beep

# --- Complétion ---------------------------------------------------------------
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' menu select
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "$ZSH_CACHE"

autoload -Uz compinit
compinit -d "$ZSH_CACHE/zcompdump"

# --- Touches ------------------------------------------------------------------
bindkey -e
zmodload zsh/terminfo

autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search

# terminfo décrit le mode « application », que zle n'active pas de lui-même :
# sans smkx, Début et Fin émettent une autre séquence que celle liée plus bas.
if (( ${+terminfo[smkx]} )); then
	zle-line-init()   { echoti smkx }
	zle-line-finish() { echoti rmkx }
	zle -N zle-line-init
	zle -N zle-line-finish
fi

typeset -A cles=(
	khome beginning-of-line
	kend  end-of-line
	kdch1 delete-char
	kcuu1 up-line-or-beginning-search
	kcud1 down-line-or-beginning-search
)
for cle in ${(k)cles}; do
	[[ -n "${terminfo[$cle]}" ]] && bindkey -- "${terminfo[$cle]}" "${cles[$cle]}"
done
unset cles cle

# Ctrl + flèches : mot à mot. Absent de terminfo, d'où la séquence xterm en dur.
bindkey '^[[1;5C' forward-word
bindkey '^[[1;5D' backward-word

# --- Alias --------------------------------------------------------------------
alias ls='ls --color=auto'
alias ll='ls -lh'
alias la='ls -lha'
alias grep='grep --color=auto'

# --- Prompt (Gnzh sur une ligne, en Catppuccin Mocha) -------------------------
autoload -Uz vcs_info add-zsh-hook
zstyle ':vcs_info:*' enable git
zstyle ':vcs_info:git:*' formats       ' %F{#f9e2af}‹%b›%f'
zstyle ':vcs_info:git:*' actionformats ' %F{#f9e2af}‹%b|%a›%f'
add-zsh-hook precmd vcs_info

# Un seul « * » quel que soit le sale — indexé, modifié ou non suivi — là où
# check-for-changes ignore le non suivi et en affiche deux. Un git status par prompt.
zstyle ':vcs_info:git*+post-backend:*' hooks git-sale
+vi-git-sale() {
	[[ -n $(git status --porcelain 2>/dev/null | head -1) ]] &&
		hook_com[branch]+='%F{#f38ba8}*%F{#f9e2af}' && ret=1
}

setopt prompt_subst
PROMPT='%(!.%F{#f38ba8}.%F{#a6e3a1})%n%f%F{#94e2d5}@%f%(!.%F{#f38ba8}.%F{#a6e3a1})%m%f %B%F{#89b4fa}%~%f%b${vcs_info_msg_0_} ➤ '
RPROMPT='%(?..%F{#f38ba8}%? ↵%f)'

# --- Plugins (paquets Debian) -------------------------------------------------
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#585b70'
[[ -r /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]] &&
	source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh

# La coloration s'enveloppe autour des widgets zle existants : elle vient après.
[[ -r /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] &&
	source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# --- Tes réglages -------------------------------------------------------------
# Sourcé en dernier : la dernière valeur écrite gagne. Un widget zle défini ici
# échappe en revanche à la coloration, sourcée juste avant.
[[ -r "${ZDOTDIR:-$HOME}/local.zsh" ]] && source "${ZDOTDIR:-$HOME}/local.zsh"

# Sinon un [[ ]] faux juste au-dessus laisse $? à 1, et le premier prompt de la
# session s'affiche en rouge.
true
