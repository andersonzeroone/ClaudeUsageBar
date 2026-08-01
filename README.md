# ClaudeUsageBar

Ícone na barra de menu do macOS que mostra a conta Claude logada e o uso/limite
da sessão (5h) e semanal. Inspirado em
[akitaonrails/ai-usagebar](https://github.com/akitaonrails/ai-usagebar), mas
reduzido a um único arquivo Swift focado só na Anthropic/Claude — sem
dependências externas (Rust, Cargo, etc.), só `swiftc`.

## Como funciona

- Lê `~/.claude.json` → `oauthAccount` para nome, e-mail e organização (só leitura).
- Lê o token OAuth do Keychain de login, item genérico `Claude Code-credentials`
  (o mesmo que o CLI `claude` já escreve lá) via `security find-generic-password`.
  **Nunca escreve de volta no Keychain.**
- Consulta `GET https://api.anthropic.com/api/oauth/usage` (endpoint não
  documentado, mesmo usado pelo `claude` CLI) para as janelas de 5 horas e 7 dias.
- Atualiza a cada 60s. Clique no ícone para abrir o menu com os detalhes, ou
  "Atualizar agora".

## Build & uso

```bash
./build.sh                 # gera ./claude-usagebar
./claude-usagebar &         # aparece na barra de menu (sem ícone no Dock)
```

Requer macOS com Command Line Tools (`xcode-select --install`) para `swiftc`,
e ter rodado `claude` pelo menos uma vez para haver credenciais no Keychain.

Não é assinado (Gatekeeper não bloqueia por ser rodado via Terminal/LaunchAgent;
se reclamar, clique com botão direito no binário → Abrir, uma vez).

## Iniciar automaticamente no login (opcional)

```bash
./install-agent.sh          # instala um LaunchAgent em ~/Library/LaunchAgents
./uninstall-agent.sh        # remove
```

## Limitações conhecidas

- Se o token de acesso expirar e o CLI `claude` não tiver deixado um
  `refreshToken` (fluxo "trusted device" mais recente), o app mostra "sessão
  expirada" — rode `claude` no Terminal para reautenticar.
- Um único vendor (Anthropic/Claude). Se quiser os outros provedores
  (OpenAI, Z.AI, etc.) do projeto original, veja o `ai-usagebar` completo.
