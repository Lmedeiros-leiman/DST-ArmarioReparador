# DST Armario Reparador

Mod para Don't Starve Together que transforma o armario vanilla em armazenamento para equipamento danificado. O clique esquerdo continua abrindo a troca de skin e o clique direito abre os slots do armario.

## O que ele faz

- Restaura durabilidade de ferramentas, armas e armaduras guardadas.
- Restaura combustivel de amuletos e roupas que usam o componente `fueled`.
- Recusa itens pereciveis, como ham bat.
- Recusa itens sem slot de equipamento, como thermal stone.
- Permite configurar 2x2, 3x3, 4x4, 5x4, 5x5, 6x6 ou 7x7. O padrao e 5x4, com 20 slots.
- O DST tem arte nativa ate 5x4. Acima de 20 slots, o mod nao adiciona uma moldura nova para os slots extras.
- Permite configurar a taxa de recuperacao entre 1% e 20% por dia DST. O padrao e 5% por dia.

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
luac5.1 -p modinfo.lua modmain.lua wardrobe_restorer_math.lua test/test_recover.lua test/test_modenv.lua
```

Os testes validam os calculos de recuperacao, os layouts de slots, o filtro de itens e o contrato de carregamento de modulos do ambiente do DST.
