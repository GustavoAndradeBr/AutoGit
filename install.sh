#!/bin/bash

# ─────────────────────────────────────────────
#  install.sh — instalador do atg
#  by Gustavo
# ─────────────────────────────────────────────

set -euo pipefail

SCRIPT_NAME="atg.sh"
BIN_DIR="$HOME/bin"
BIN_NAME="atg"

echo ""
echo "  Instalando atg..."
echo ""

# Verifica se o script existe no diretorio atual
if [ ! -f "$SCRIPT_NAME" ]; then
    echo "  Erro: $SCRIPT_NAME nao encontrado no diretorio atual."
    echo "  Rode este instalador na mesma pasta onde esta o $SCRIPT_NAME."
    exit 1
fi

# Verifica dependencias
for cmd in git fzf; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "  Aviso: '$cmd' nao encontrado. Instale antes de usar o atg."
    fi
done

# Cria ~/bin se nao existir
mkdir -p "$BIN_DIR"

# Copia o script para ~/bin/atg
cp "$SCRIPT_NAME" "$BIN_DIR/$BIN_NAME"
chmod +x "$BIN_DIR/$BIN_NAME"

echo "  OK: copiado para $BIN_DIR/$BIN_NAME"

# Detecta o arquivo de perfil do shell
PROFILE_FILE=""
if [ -n "${BASH_VERSION:-}" ]; then
    if [ -f "$HOME/.bashrc" ]; then
        PROFILE_FILE="$HOME/.bashrc"
    else
        PROFILE_FILE="$HOME/.bash_profile"
    fi
elif [ -n "${ZSH_VERSION:-}" ]; then
    PROFILE_FILE="$HOME/.zshrc"
else
    PROFILE_FILE="$HOME/.bashrc"
fi

# Adiciona ~/bin ao PATH se ainda nao estiver
if ! grep -q 'export PATH="$HOME/bin:$PATH"' "$PROFILE_FILE" 2>/dev/null; then
    echo '' >> "$PROFILE_FILE"
    echo '# Adicionado pelo instalador do atg' >> "$PROFILE_FILE"
    echo 'export PATH="$HOME/bin:$PATH"' >> "$PROFILE_FILE"
    echo "  OK: PATH atualizado em $PROFILE_FILE"
else
    echo "  OK: PATH ja estava configurado em $PROFILE_FILE"
fi

echo ""
echo "  Instalacao concluida!"
echo ""
echo "  Para comecar a usar agora, rode:"
echo "    source $PROFILE_FILE"
echo ""
echo "  Depois, em qualquer repositorio git, basta rodar:"
echo "    atg"
echo ""