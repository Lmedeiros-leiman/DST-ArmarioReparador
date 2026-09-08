name = "Wardrobe Restorer (Armario Restaurador)"
description = [[O armario vira um bau de ate 20 slots e restaura a durabilidade do que estiver guardado nele.

Aceita apenas equipamento (ferramentas, armas, armaduras, amuletos). Itens que apodrecem (como ham bat) e itens nao equipaveis (como thermal stone) sao bloqueados. Durabilidade cobre usos, armadura e combustivel (fueled).

Itens com durabilidade recuperam 5% por dia por padrao: de 0% a 100% em 20 dias, aos poucos, tick a tick.

Clique esquerdo abre o menu de troca de skin (como sempre). Clique direito abre o armazenamento.]]
author = "Leonardo"
version = "1.0.0"

forumthread = ""

api_version = 10

dst_compatible = true
dont_starve_compatible = false
reign_of_giants_compatible = false

all_clients_require_mod = true
client_only_mod = false

icon = nil
icon_atlas = nil

server_filter_tags =
{
    "wardrobe",
    "storage",
}

configuration_options =
{
    {
        name = "num_slots",
        label = "Slots",
        hover = "Quantidade de slots do armario. 20 e o maior layout com interface nativa do jogo.",
        options =
        {
            { description = "9 (bau 3x3)", data = 9 },
            { description = "16 (4x4)", data = 16 },
            { description = "20 (5x4)", data = 20 },
        },
        default = 20,
    },
    {
        name = "recovery_rate",
        label = "Recuperacao (%/dia)",
        hover = "Durabilidade recuperada por dia. 5% leva um item de 0% a 100% em 20 dias.",
        options =
        {
            { description = "1% (100 dias)", data = 1 },
            { description = "2% (50 dias)", data = 2 },
            { description = "3% (33 dias)", data = 3 },
            { description = "4% (25 dias)", data = 4 },
            { description = "5% (20 dias)", data = 5 },
            { description = "6% (17 dias)", data = 6 },
            { description = "8% (13 dias)", data = 8 },
            { description = "10% (10 dias)", data = 10 },
            { description = "15% (7 dias)", data = 15 },
            { description = "20% (5 dias)", data = 20 },
        },
        default = 5,
    },
}
