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

commit_interativo() {
    if git diff --quiet && git diff --cached --quiet; then
        echo "  Nada para commitar. Working tree limpa."
        return
    fi

    echo ""
    echo "  Status atual:"
    git -c color.ui=always status --short
    echo ""

    local files exit_code
    files=$( (echo "$VOLTAR"; git status --short) | fzf -m \
        "${FZF_OPTS[@]}" \
        --header "  Commit  |  TAB para selecionar multiplos arquivos" \
        --height 60% \
        --preview 'f=$(echo {} | awk "{print \$2}"); [ "$f" = "voltar" ] && echo "  Voltar ao menu principal" || git -c color.ui=always diff "$f" 2>/dev/null || git -c color.ui=always diff --cached "$f"')
    exit_code=$?

    fzf_check $exit_code || return 0
    [[ "$files" == "$VOLTAR" ]] && return 0

    [ -z "$files" ] && { echo "  Nenhum arquivo selecionado."; return; }

    echo "$files" | grep -v "← voltar" | awk '{print $2}' | xargs git add
    echo ""
    git -c color.ui=always diff --cached --stat
    echo ""

    local commit_type
    commit_type=$( (echo "$VOLTAR"; printf "feat\nfix\ndocs\nstyle\nrefactor\ntest\nchore\nbuild\nci\nperf\nrevert") | fzf +m \
        "${FZF_OPTS[@]}" \
        --header "  Tipo do commit (Conventional Commits)" \
        --height 40%)
    exit_code=$?
    fzf_check $exit_code || { git reset HEAD &>/dev/null; return 0; }
    [[ "$commit_type" == "$VOLTAR" ]] && { git reset HEAD &>/dev/null; return 0; }

    read -rp "  Scope (opcional, ex: auth, ui): " scope
    read -rp "  Mensagem: " msg
    [ -z "$msg" ] && { echo "  Commit cancelado."; git reset HEAD &>/dev/null; return; }

    local full_msg
    if [ -n "$scope" ]; then
        full_msg="$commit_type($scope): $msg"
    else
        full_msg="$commit_type: $msg"
    fi

    git commit -m "$full_msg"
    echo ""
    echo "  OK: $full_msg"

    confirm "Fazer push agora?" && git push && echo "  OK: push realizado." || true
}

undo_commit() {
    if ! git log -1 &>/dev/null; then
        echo "  Nenhum commit ainda neste repositorio."
        return
    fi

    echo ""
    echo "  Ultimo commit:"
    git -c color.ui=always log -1 --oneline
    echo ""

    local action exit_code
    action=$( (echo "$VOLTAR"; printf "Editar mensagem (amend)\nDesfazer ultimo commit (mantem mudancas)\nDesfazer ultimo commit (descarta mudancas)") | fzf +m \
        "${FZF_OPTS[@]}" \
        --header "  Undo  |  ultimo commit sera afetado" \
        --height 30%)
    exit_code=$?
    fzf_check $exit_code || return 0
    [[ "$action" == "$VOLTAR" ]] && return 0

    case "$action" in
        *"Editar mensagem"*)
            local current_msg new_msg
            current_msg=$(git log -1 --pretty=%B)
            echo "  Mensagem atual: $current_msg"
            read -rp "  Nova mensagem (vazio para cancelar): " new_msg
            [ -z "$new_msg" ] && { echo "  Cancelado."; return; }
            git commit --amend -m "$new_msg"
            echo "  OK: mensagem atualizada."
            ;;
        *"mantem mudancas"*)
            confirm "Desfazer o ultimo commit e manter as mudancas no working tree?" || { echo "  Cancelado."; return; }
            git reset --soft HEAD~1
            echo "  OK: commit desfeito, mudancas mantidas (staged)."
            ;;
        *"descarta mudancas"*)
            confirm "ATENCAO: isso APAGA as mudancas do ultimo commit. Confirmar?" || { echo "  Cancelado."; return; }
            confirm "Tem certeza mesmo? Essa acao nao tem volta" || { echo "  Cancelado."; return; }
            git reset --hard HEAD~1
            echo "  OK: commit e mudancas descartados."
            ;;
    esac
}

stash_menu() {
    local action exit_code

    action=$( (echo "$VOLTAR"; printf "Salvar stash\nAplicar stash\nDeletar stash\nVer todos os stashes") | fzf +m \
        "${FZF_OPTS[@]}" \
        --header "  Stash" \
        --height 30%)
    exit_code=$?
    fzf_check $exit_code || return 0
    [[ "$action" == "$VOLTAR" ]] && return 0

    case "$action" in
        *"Salvar"*)
            read -rp "  Nome do stash (opcional): " stash_name
            if [ -n "$stash_name" ]; then
                git stash push -m "$stash_name" && echo "  OK: stash '$stash_name' salvo."
            else
                git stash && echo "  OK: stash salvo."
            fi
            ;;
        *"Aplicar"*)
            local stash
            stash=$( (echo "$VOLTAR"; git stash list) | fzf +m \
                "${FZF_OPTS[@]}" \
                --header "  Selecione o stash para aplicar" \
                --height 40% \
                --preview 'r=$(echo {} | cut -d: -f1); [ "$r" = "← voltar" ] && echo "  Voltar" || git -c color.ui=always stash show -p "$r"')
            fzf_check $? || return 0
            [[ "$stash" == "$VOLTAR" ]] && return 0
            git stash pop "$(echo "$stash" | cut -d: -f1)"
            echo "  OK: stash aplicado."
            ;;
        *"Deletar"*)
            local stash
            stash=$( (echo "$VOLTAR"; git stash list) | fzf +m \
                "${FZF_OPTS[@]}" \
                --header "  ATENCAO: Deletar stash" \
                --height 40%)
            fzf_check $? || return 0
            [[ "$stash" == "$VOLTAR" ]] && return 0
            local ref
            ref=$(echo "$stash" | cut -d: -f1)
            confirm "Deletar '$ref'?" && git stash drop "$ref" && echo "  OK: stash deletado."
            ;;
        *"Ver"*)
            git stash list
            ;;
    esac
}

show_log() {
    git log \
        --graph \
        --color=always \
        --format="%C(auto)%h%d %s %C(dim)%cr %C(bold blue)<%an>%Creset" \
        | fzf \
            "${FZF_OPTS[@]}" \
            --ansi \
            --no-sort \
            --header "  Log  |  $REPO_NAME [$CURRENT_BRANCH]  |  ESC para voltar" \
            --height 90% \
            --preview 'echo {} | grep -o "[a-f0-9]\{7,\}" | head -1 | xargs -I{} git -c color.ui=always show --stat {}'
    return 0
}

pull_fetch() {
    local action exit_code

    action=$( (echo "$VOLTAR"; printf "Pull\nPush\nFetch\nFetch --all") | fzf +m \
        "${FZF_OPTS[@]}" \
        --header "  Sync" \
        --height 25%)
    exit_code=$?
    fzf_check $exit_code || return 0
    [[ "$action" == "$VOLTAR" ]] && return 0

    case "$action" in
        *"Pull"*)         git pull ;;
        *"Push"*)
            if git push 2>/tmp/push_err; then
                echo "  OK: push realizado."
            else
                cat /tmp/push_err
                if grep -q "no upstream branch" /tmp/push_err; then
                    confirm "Branch sem upstream. Criar com 'push -u origin $CURRENT_BRANCH'?" \
                        && git push -u origin "$CURRENT_BRANCH" && echo "  OK: upstream configurado e push feito."
                fi
            fi
            rm -f /tmp/push_err
            ;;
        *"Fetch --all"*)  git fetch --all --prune && echo "  OK: fetch --all concluido." ;;
        *"Fetch"*)        git fetch --prune && echo "  OK: fetch concluido." ;;
    esac
}

# MENU PRINCIPAL
function main() {
    local dirty_marker=""
    git diff --quiet && git diff --cached --quiet || dirty_marker=" [*]"

    local remote_info=""
    if git remote get-url origin &>/dev/null; then
        remote_info=$(git remote get-url origin | sed 's/.*github.com[:/]//' | sed 's/\.git//')
    fi

    local header_line="  $REPO_NAME"
    [ -n "$remote_info" ] && header_line+="  |  $remote_info"
    header_line+="  |  Branch atual: $CURRENT_BRANCH$dirty_marker"

    local footer_line="  ↑/↓ navegar   enter selecionar   esc cancelar   |   by Gustavo Andrade · github.com/GustavoAndradeBr"

    local options=(
        "1 - switch  |  Trocar de branch"
        "2 - create  |  Criar nova branch"
        "3 - merge   |  Mergear branch"
        "4 - delete  |  Deletar branch"
        "5 - commit  |  Commit interativo"
        "6 - stash   |  Gerenciar stash"
        "7 - log     |  Ver historico"
        "8 - sync    |  Push / Pull / Fetch"
        "9 - undo    |  Desfazer/editar ultimo commit"
        "0 - exit    |  Sair"
    )

    local selected exit_code
    selected=$(printf "%s\n" "${options[@]}" | fzf +m \
        "${FZF_OPTS[@]}" \
        --header "$header_line" \
        --footer "$footer_line" \
        --height 100% \
        --no-preview \
        --padding '1,2')
    exit_code=$?

    fzf_check $exit_code || exit 0

    echo ""
    case "$selected" in
        *"switch"*)  switch_branch ;;
        *"create"*)  create_branch ;;
        *"merge"*)   merge_branch ;;
        *"delete"*)  delete_branch ;;
        *"commit"*)  commit_interativo ;;
        *"stash"*)   stash_menu ;;
        *"log"*)     show_log ;;
        *"sync"*)    pull_fetch ;;
        *"undo"*)    undo_commit ;;
        *"exit"*)    exit 0 ;;
    esac

    echo ""
    CURRENT_BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null || echo "HEAD detached")
    sleep 1
    main
}

main