# Quando usar cada ferramenta

O projeto tem três caminhos para mudar o jogo. Cada um tem um papel, e misturar os papéis faz um sobrescrever o outro.

| Tarefa | Ferramenta | Por quê |
| --- | --- | --- |
| Scripts (servidor, cliente, módulos, configs) | **Git + Rojo** (`src/`) | O repositório é a fonte da verdade do código. O Rojo sobrescreve no Studio qualquer script que esteja em `src/`, então editar script direto no Studio se perde. |
| Mapa, lotes, praça, arena, iluminação, posição de peças | **MCP do Roblox Studio** | É geometria dentro do place, não código. Depois de montar, salve o place (e publique). |
| Layout de telas montadas à mão no Studio | **MCP do Roblox Studio** | Mesma razão. O HUD do protótipo é criado por código; telas novas podem seguir qualquer um dos dois, mas só um por tela. |
| Testar: Play, ler o Output, conferir erros | **MCP do Roblox Studio** | Só ele roda o jogo e lê o console. |
| Inserir um asset já publicado (modelo, imagem, som) no place | **MCP do Roblox Studio** | Usa o asset ID que o ForgeGUI devolve. |
| Criar arte: ícones, botões, painéis, thumbnail, ícone do jogo, ícones de game pass e badge | **ForgeGUI** (`generation_gui`, `generation_image`) | Gera a imagem; não mexe no place. |
| Criar modelos 3D (caixas de poder, gerador, cofre, decoração) | **ForgeGUI** (`generation_model_3d`) | Gera GLB; pode publicar direto no Roblox como Model. |
| Sons e música (coleta de aura, roubo, golpes, música da arena) | **ForgeGUI** (`generation_sound_effect`, `generation_music`) | Gera MP3; pode publicar como Audio. |
| Skybox e texturas | **ForgeGUI** (`asset_prepare` com `skybox` ou `texture`) | Converte panorama ou mapas PBR para o formato do Roblox. |
| Publicar a arte no Roblox e pegar o asset ID | **ForgeGUI** (`artifact_publish`, conexão `@robson_developer`) | Devolve o ID que vai para `src/shared/Config` ou para o place. |
| Procurar modelos prontos na Toolbox | **ForgeGUI** (`toolbox_search`) | Busca; inserir no place continua sendo pelo MCP do Studio. |

Fluxo típico de um asset novo: ForgeGUI gera → ForgeGUI publica e devolve o asset ID → o ID entra na config em `src/shared/Config` (via Git) ou é inserido no place pelo MCP do Studio → MCP do Studio testa.

Gerar no ForgeGUI gasta créditos da conta. Leituras, buscas e preparo de assets (`asset_prepare`) não gastam.

## Referências visuais

As imagens em `docs/referencias/` mostram o alvo:

- `arena-batalha-*.png`: combate da arena com destroços voando, explosões de luz e poeira (estilo battlegrounds de anime).
- `base-steal-a-brainrot.png`: lote com placa do dono, itens expostos na base e cores fortes.
- `porta-tycoon.png`: porta/portão de neon na entrada do lote, como no tycoon de super-heróis.
