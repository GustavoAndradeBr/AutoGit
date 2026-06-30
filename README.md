# atg.sh

> Interface interativa para Git no terminal, construída com Bash + fzf.

Navega branches, faz commits com Conventional Commits, gerencia stash e visualiza o histórico — tudo sem digitar um comando sequer.

---

## Demo

```
  ⬡  atg  │  user/repo  │  branch: main ●

  switch     Trocar de branch
  create     Criar nova branch
  merge      Mergear branch
  delete     Deletar branch
  commit     Commit interativo
  stash      Gerenciar stash
  log        Ver histórico
  sync       Push / Pull / Fetch
  undo       Desfazer/editar ultimo commit
  exit       Sair
```

O `●` no header indica que há mudanças não commitadas no working tree.

---

## Funcionalidades

### Branches

- **Switch** — lista todas as branches com preview do log de cada uma
- **Create** — cria nova branch com opção de checkout automático
- **Merge** — seleciona a branch de origem com diff em tempo real como preview
- **Delete** — tenta deleção segura (`-d`); se houver commits não mergeados, oferece force delete (`-D`) com confirmação

### Commit interativo

1. Mostra o `git status` atual
2. Seleção de arquivos via fzf com **multi-select** (TAB) e preview do diff
3. Escolha do tipo via [Conventional Commits](https://www.conventionalcommits.org/) (`feat`, `fix`, `docs`, `refactor`...)
4. Scope opcional (ex: `auth`, `ui`)
5. Mensagem do commit
6. Pergunta se quer fazer push logo em seguida

Resultado: `feat(auth): add login with Google`

### Stash

- Salvar com nome opcional
- Aplicar (com preview do patch)
- Deletar com confirmação
- Listar todos os stashes

### Log

- Histórico com `--graph` colorido
- Preview lateral de cada commit (stat)
- `Ctrl+D` → abre o diff completo no `less`

### Sync

- `git push`
- `git pull`
- `git fetch --prune`
- `git fetch --all --prune`

---

## Instalação

**Dependências:**

- `git`
- [`fzf`](https://github.com/junegunn/fzf)

```bash
# macOS
brew install fzf

# Ubuntu/Debian
sudo apt install fzf

# Arch
sudo pacman -S fzf
```

**Instalar o script:**

```bash
# Clonar o repositório
git clone https://github.com/GustavoAndradeBr/AutoGit.git

# Dar permissão de execução
chmod +x atg.sh

# Instalar globalmente (opcional)
sudo mv atg.sh /usr/local/bin/auto-git
```

**Usar:**

```bash
# Se instalado globalmente
atg.sh

# Ou direto
./atg.sh
```

---

## Como funciona

O script é 100% Bash. Cada tela interativa é um processo `fzf` recebendo dados via pipe do Git. O menu principal roda em loop recursivo — após cada ação, volta pro menu automaticamente atualizando a branch atual.

Algumas decisões técnicas:

- **`set -euo pipefail`** — qualquer erro não tratado encerra o script, evitando comportamento silencioso inesperado
- **`fzf_check`** — captura o exit code do fzf imediatamente após a chamada (exit 130 = usuário pressionou ESC/Ctrl+C), porque qualquer comando seguinte sobrescreveria `$?`
- **`other_branches`** — filtra a branch atual da lista pra não aparecer como opção em switch/merge/delete
- **Conventional Commits** — o commit interativo força a escolha de um tipo antes da mensagem, padronizando o histórico automaticamente

---

## Estrutura do código

```
atg.sh
├── Validações iniciais
│   ├── Checa se git e fzf estão instalados
│   └── Checa se está dentro de um repositório git
├── Configuração global do fzf (FZF_OPTS)
├── Helpers
│   ├── fzf_check()      — trata cancelamento via ESC
│   ├── other_branches() — lista branches exceto a atual
│   └── confirm()        — prompt de confirmação s/N
├── Funções principais
│   ├── switch_branch()
│   ├── create_branch()
│   ├── merge_branch()
│   ├── delete_branch()
│   ├── commit_interativo()
│   ├── undo_commit()
│   ├── stash_menu()
│   ├── show_log()
│   └── pull_fetch()
└── main() — menu principal em loop recursivo
```
