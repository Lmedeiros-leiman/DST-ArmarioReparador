# DST Armario Reparador

Mod para Don't Starve Together que transforma o armario vanilla em armazenamento para equipamento danificado. O clique esquerdo abre os slots do armario e o clique direito abre a troca de skin.

## O que ele faz

- Restaura durabilidade de ferramentas, armas e armaduras guardadas.
- Restaura combustivel de itens que usam o componente `fueled` (roupas, amuletos, fontes de luz e outros).
- Recusa itens pereciveis, como ham bat.
- Recusa itens sem slot de equipamento, como thermal stone. A unica excecao e a flauta de pa (pan flute).
- Separa os itens em categorias. Cada uma tem tres opcoes na configuracao ("Item categories"):
  - "Store <categoria>": se a categoria pode ser guardada. Padrao: sim. Recusada, ela nao entra no armario, e os itens dela que ja estavam guardados param de ser reparados.
  - "Repair <categoria>": se a categoria e reparada. Padrao: sim. So vale com "Enable repair?" ativado.
  - "Half rate <categoria>": se a categoria recupera na metade da taxa. Padrao: sim para Magicos, Magia antiga, Equipamento de chefe e Equipamento de kit, nao para as outras.
- Um item fica na primeira categoria que se aplica, nesta ordem:
  1. Recarregaveis: regadores e outros itens que se reabastecem em vez de reparar.
  2. Equipamento de kit: Brightshade, Void cloth e W.A.R.B.I.S. (consertados com kit de reparo), mais Dreadstone (se regenera sozinho).
  3. Equipamento de chefe: dropado por um chefe ou feito com um drop de chefe (Bone Armor, Shield of Terror, Scalemail, Hibearnation Vest, Eyebrella e outros).
  4. Equipamento antigo: coroa, armadura e clava de Thulecite.
  5. Magia antiga: cajados e amuletos da aba Ancient (Deconstruction Staff, Lazy Explorer, Star Caller's Staff, Moon Caller's Staff, Construction Amulet, Magiluminescence e Lazy Forager).
  6. Magicos: cajados de fogo, gelo e teleporte, amuletos, night armor, dark sword, bat bat, one-man band, Alarming Clock e a flauta de pa.
  7. Fontes de luz: tocha, Morning Star, isqueiro, lanterna, miner hat, moggles e red lantern.
  8. Roupas: itens que se gastam com o uso e podem ser costurados.
  9. Ferramentas, armas e armaduras: todo o resto.
- Permite configurar 2x2, 3x3, 4x4, 5x4, 5x5, 6x6 ou 7x7. O padrao e 5x4, com 20 slots.
- O DST tem arte nativa ate 5x4. As grades 5x5, 6x6 e 7x7 usam a moldura quadrada 4x4 ampliada. Quando a grade nao cabe acima do personagem, ela abre ao lado dele, no lado oposto ao armario.
- Permite configurar a taxa de recuperacao entre 1% e 20% por dia DST. O padrao e 5% por dia.
- Permite desativar o reparo ("Enable repair?"). Desativado, o armario vira apenas armazenamento e todas as opcoes de reparo ("Recovery", "Repair" e "Half rate") sao ignoradas. O padrao e ativado.

## Antes de desativar

Desativar o mod apaga tudo o que estiver guardado nos armarios, porque o jogo descarta o conteudo de um componente que deixou de existir. Esvazie os armarios (ou martele-os, o que derruba o conteudo no chao) antes de desativar o mod.

## Instalacao local

1. Feche Don't Starve Together.
2. Copie estes arquivos para `mods/wardrobe_restorer` na instalacao do jogo. O caminho Steam padrao no Linux e `~/.local/share/Steam/steamapps/common/Don't Starve Together/mods/wardrobe_restorer`.
3. Ative o mod para o servidor e configure os slots e a taxa de recuperacao na tela de mods.
4. Reinicie o servidor depois de alterar configuracoes ou arquivos do mod.

O mod precisa estar ativo para todos os jogadores do servidor. Em um servidor dedicado, todos precisam usar a mesma configuracao de slots para a interface ficar alinhada com o servidor.

## Testes locais

Requer Lua 5.1.

```bash
lua5.1 test/test_recover.lua
lua5.1 test/test_modenv.lua
lua5.1 test/test_modmain.lua
lua5.1 test/test_categories.lua
luac5.1 -p modinfo.lua modmain.lua wardrobe_restorer_math.lua test/test_recover.lua test/test_modenv.lua test/test_modmain.lua test/test_categories.lua
```

Os testes validam os calculos de recuperacao, os layouts de slots, o filtro de itens, as categorias e suas opcoes, o modmain contra um ambiente DST simulado e o contrato de carregamento de modulos do ambiente do DST.
