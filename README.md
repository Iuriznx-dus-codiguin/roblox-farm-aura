# Farm Aura: Steal Aura!

Jogo de Roblox: cada jogador farma aura no próprio lote, rouba poderes dos lotes dos outros e arrisca a aura na arena.
O design está no GDD do MVP (doc "Farm Aura — GDD do MVP").

## O que já existe

Protótipo do loop de aura:

- 12 lotes em círculo ao redor da praça (gerados pelo código se o place não tiver `Workspace.Plots`)
- Gerador que enche o coletor do lote; o dono pisa no coletor para pegar a aura
- Cofre: 20% de cada coleta vai para o cofre do lote; o dono pisa nele para pegar
- Upgrade do gerador (30 níveis, +40% de geração e +60% de custo por nível)
- Faixa de aura pelo pico desde a última derrota ou rebirth
- Geração offline a 25% por até 2 horas
- Perfil salvo no DataStore (trava de sessão, autosave a cada 2 min, ao sair e ao fechar o servidor)
- HUD com aura, faixa, progresso, aura/s, cofre e botão de upgrade

## Como rodar no Studio

1. Instale o [Rokit](https://github.com/rojo-rbx/rokit) e, na pasta do projeto, rode `rokit install`.
2. No Roblox Studio, instale o plugin do Rojo (Plugins > Manage Plugins, ou `rojo plugin install`).
3. Crie um place vazio (Baseplate) e salve.
4. No terminal, na pasta do projeto: `rojo serve`.
5. No Studio, abra o plugin Rojo e clique em **Connect**. O código aparece em ReplicatedStorage, ServerScriptService e StarterPlayerScripts.
6. Para o DataStore funcionar no Studio: publique o place e ative *Game Settings > Security > Enable Studio Access to API Services*. Sem isso o jogo roda com dados em memória e avisa no Output.
7. Aperte Play.

## Estrutura

```
src/shared   código que roda no cliente e no servidor (configs, fórmulas, remotes)
src/server   serviços do servidor (DataService, PlotService, AuraService)
src/client   HUD e entrada do jogador
tests        testes da lógica pura, rodam fora do Roblox
```

Os números do jogo ficam em `src/shared/Config`. Mudar um valor ali não exige mexer no resto do código.

## Ferramentas

- `stylua src` formata o código
- `selene src` procura erros comuns
- `python3 tests/run.py` roda os testes de src/shared (precisa do CLI `luau`)
