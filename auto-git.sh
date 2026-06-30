#!/bin/bash

# ─────────────────────────────────────────────
#  gitui — Git TUI interativo com fzf
#  by Gustavo
# ─────────────────────────────────────────────

set -euo pipefail

for cmd in git fzf; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "Dependencia nao encontrada: $cmd"
        exit 1
    fi
done

if ! git rev-parse --is-inside-work-tree &>/dev/null 2>&1; then
    echo "Nao e um repositorio git."
    exit 1
fi

# ── fzf cor bonitinho e verde
FZF_OPTS=( 
    --layout reverse
    --border rounded
    --color "bg:#0a0a0a,bg+:#0d1f0d,fg:#00cc44,fg+:#00ff55"
    --color "header:#00ff55,info:#007722,prompt:#00cc44,pointer:#00ff55"
    --color "preview-bg:#050f05,border:#00aa33,hl:#00ff55,hl+:#88ffaa"
    --color "preview-border:#007722,gutter:#0a0a0a"
    --prompt "  > "
    --pointer ">"
    --marker "*"
)

CURRENT_BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null || echo "HEAD detached")
REPO_NAME=$(basename "$(git rev-parse --show-toplevel)")

fzf_check() {
    local exit_code=$1
    if [ "$exit_code" -eq 130 ]; then
        echo ""
        echo "  Cancelado."
        return 1
    fi
    return 0
}

other_branches() {
    git branch | grep -v "^\* "
}

confirm() {
    local msg="$1"
    read -rp "  $msg (s/N): " ans
    [[ "$ans" =~ ^[sS]$ ]]
}

VOLTAR="← voltar"

function switch_branch() {
    local selected exit_code

    selected=$( (echo "$VOLTAR"; other_branches) | fzf +m \
        "${FZF_OPTS[@]}" \
        --header "  Switch Branch  |  branch atual: $CURRENT_BRANCH" \
        --height 50% \
        --preview 'b=$(echo {} | tr -d " *"); [ "$b" = "← voltar" ] && echo "  Voltar ao menu principal" || git -c color.ui=always log --oneline --graph -20 "$b"')
    exit_code=$?

    fzf_check $exit_code || return 0
    [[ "$selected" == "$VOLTAR" ]] && return 0

    selected=$(echo "$selected" | tr -d " *")
    git switch "$selected"
    echo "  OK: trocado para '$selected'"
}


function create_branch() {
    read -rp "  Nome da nova branch (vazio para voltar): " branch_name
    [ -z "$branch_name" ] && { echo "  Voltando..."; return; }

    read -rp "  Fazer checkout automatico? (S/n): " checkout
    if [[ ! "$checkout" =~ ^[nN]$ ]]; then
        git switch -c "$branch_name"
        echo "  OK: branch '$branch_name' criada e ativada."
    else
        git branch "$branch_name"
        echo "  OK: branch '$branch_name' criada."
    fi
}

function merge_branch() {
    local selected exit_code

    selected=$( (echo "$VOLTAR"; other_branches) | fzf +m \
        "${FZF_OPTS[@]}" \
        --header "  Merge  |  destino: $CURRENT_BRANCH" \
        --height 80% \
        --preview "b=\$(echo {} | tr -d ' *'); [ \"\$b\" = '← voltar' ] && echo '  Voltar ao menu principal' || git -c color.ui=always diff $CURRENT_BRANCH \"\$b\" -- 2>/dev/null | head -80")
    exit_code=$?

    fzf_check $exit_code || return 0
    [[ "$selected" == "$VOLTAR" ]] && return 0

    selected=$(echo "$selected" | tr -d " *")
    echo "  Mergeando '$selected' -> '$CURRENT_BRANCH'..."
    git merge "$selected"
}

function delete_branch() {
    local selected exit_code

    selected=$( (echo "$VOLTAR"; other_branches) | fzf +m \
        "${FZF_OPTS[@]}" \
        --header "  ATENCAO: Deletar Branch  |  branch atual: $CURRENT_BRANCH" \
        --height 50% \
        --preview 'b=$(echo {} | tr -d " *"); [ "$b" = "← voltar" ] && echo "  Voltar ao menu principal" || git -c color.ui=always log --oneline --graph -15 "$b"')
    exit_code=$?

    fzf_check $exit_code || return 0
    [[ "$selected" == "$VOLTAR" ]] && return 0

    selected=$(echo "$selected" | tr -d " *")

    confirm "Deletar '$selected'?" || { echo "  Cancelado."; return; }

    if ! git branch -d "$selected" 2>/dev/null; then
        echo "  Branch com commits nao mergeados."
        confirm "Forcar delecao (-D)?" && git branch -D "$selected" && echo "  OK: deletada." || echo "  Cancelado."
    else
        echo "  OK: branch '$selected' deletada."
    fi
}


function main (){

    option=(\
        "1 - Switch Branch" \
        "2 - Merge Branch" \
        "3 - Delete Branch" \
        "4 - Exit" \
    )

    selected=$(for opt in "${option[@]}"; do echo "$opt"; done | fzf +m \
        --header "Select an option:" \
        --height 40% \
        --layout reverse \
        --border \
        --color bg:#222222)

    exit_code=$?
    fzf_check $exit_code || return 0

    case "$selected" in 
        ${option[0]})
            echo "Switching Branch..."
            switch_branch
            exit 0
        ;;
        ${option[1]})
            echo "Merging Branch..."
            merge
            exit 0
        ;;
        ${option[2]})
            echo "Deleting Branch..."
            delete_branch
            exit 0
        ;; 
        ${option[3]})
            echo "Exiting..."
            exit 0
        ;;
        *)
            echo "Invalid option. Exiting..."
            exit 1
        ;;
    esac      
}

main
