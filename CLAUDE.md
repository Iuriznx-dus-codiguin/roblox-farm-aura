# Farm Aura — notas para o Claude

- O dono do projeto escreve em português (BR). Responda em português; comentários no código também em português.
- Fonte das regras: o GDD do MVP. Números ficam em `src/shared/Config/*`, nunca espalhados no código.
- Toda conta de aura, roubo, dano e compra acontece no servidor. O cliente só mostra e pede.
- Rojo sincroniza `src/` para o Studio (veja `default.project.json`). Não edite scripts direto no Studio.
- Arquivos `.luau`, `--!strict` no topo, StyLua com tabs (`stylua.toml`).
- Antes de commitar: `stylua src`, `selene src`, `rojo build -o /tmp/test.rbxl` e `python3 tests/run.py`.
- Serviços do servidor seguem o padrão `Service.start()` chamado em `src/server/init.server.luau`, na ordem de dependência.
- Divisão entre Git/Rojo, MCP do Roblox Studio e ForgeGUI: veja `docs/FERRAMENTAS.md`. Resumo: código pelo Git, mapa e testes pelo Studio, arte/modelos/sons pelo ForgeGUI.
