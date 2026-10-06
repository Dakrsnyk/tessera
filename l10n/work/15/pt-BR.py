from common import write
T = [
# 0
"Mantenha o quadril no chão.",
"Empurre devagar com as mãos para levantar o peito.",
"Inspire ao subir, expire ao descer.",
"Até sentir um alongamento agradável na barriga, sem dor nas costas.",
"Cotovelos levemente flexionados.",
"Ombros para baixo, longe das orelhas.",
"Tirar o quadril do chão.",
"Forçar o arqueamento.",
"Frutas", "Legumes e verduras",
# 10
"Carboidratos", "Laticínios", "Castanhas e sementes", "Pratos", "Lanches", "Bebidas", "Molhos e açúcares",
"1 maçã média", "Maçã", "1 banana",
# 20
"Banana", "1 laranja", "Laranja", "1 tangerina", "Tangerina", "1 xícara", "Morangos", "Mirtilos", "Framboesas", "Uvas",
# 30
"1 pera", "Pera", "1 pêssego", "Pêssego", "1 ameixa", "Ameixa", "Cerejas", "1 kiwi", "Kiwi", "Manga",
# 40
"Abacaxi", "1 fatia", "Melancia", "Melão cantalupo", "Toranja", "½ toranja", "Abacate", "½ abacate", "1 tigelinha", "Purê de maçã sem açúcar",
# 50
"1 caixinha", "Uvas-passas", "3 tâmaras", "Tâmaras", "Brócolis", "1 cenoura", "Cenoura", "1 tomate", "Tomate", "Pepino",
# 60
"½ pepino", "Alface", "1 xícara crua", "Espinafre", "Couve kale", "1 pimentão", "Pimentão", "1 cebola", "Cebola", "Vagem",
# 70
"Couve-flor", "Repolho", "Couve-de-bruxelas", "6 aspargos", "Aspargos", "1 talo", "Aipo", "Berinjela", "1 beterraba", "Beterraba",
# 80
"Cogumelos", "Abobrinha", "1 espiga", "Milho", "Ervilhas", "½ xícara", "Edamame", "1 média", "Batata cozida", "Batata-doce cozida",
# 90
"1 tigela", "Salada verde (sem molho)", "Arroz branco cozido", "Arroz integral cozido", "Macarrão cozido", "Macarrão integral cozido", "Macarrão de arroz cozido", "Quinoa cozida", "Cuscuz cozido", "Aveia em flocos",
# 100
"½ xícara seca", "Mingau de aveia feito com água", "Pão branco", "Pão integral", "1 pedaço", "Baguete", "1 bagel", "Bagel", "1 pita", "Pão sírio",
# 110
"1 muffin", "Muffin inglês", "1 tortilla", "Tortilla de trigo", "1 croissant", "Croissant", "1 panqueca", "Panqueca americana (pancake)", "1 waffle", "Waffle",
# 120
"Cereal de milho", "Granola", "5 biscoitos salgados", "Biscoitos salgados", "1 porção média", "Batata frita", "Peito de frango cozido", "1 coxa", "Coxa de frango cozida", "Peito de peru cozido",
# 130
"Carne moída (semimagra) cozida", "1 bife", "Bife de alcatra cozido", "Lombo de porco cozido", "Presunto", "2 fatias", "Bacon cozido", "1 linguiça", "Linguiça de porco cozida", "Salsicha defumada (cachorro-quente)",
# 140
"1 filé", "Salmão cozido", "Bacalhau cozido", "Tilápia cozida", "Atum em lata (na água)", "1 lata", "Sardinha em lata", "Camarão cozido", "1 ovo grande", "Ovo",
# 150
"1 clara", "Clara de ovo", "Tofu firme", "Lentilhas cozidas", "Grão-de-bico cozido", "Feijão-preto cozido", "Feijão-vermelho cozido", "1 scoop", "Proteína em pó (whey)", "Leite 2%",
# 160
"Leite 3,25%", "Leite desnatado", "Leite achocolatado", "Iogurte grego natural 0%", "¾ xícara", "Iogurte grego natural 2%", "1 pote", "Iogurte com frutas", "Kefir natural", "Cheddar",
# 170
"Muçarela", "Queijo suíço", "Feta", "1 colher de sopa", "Parmesão", "Queijo cottage", "2 colheres de sopa", "Cream cheese", "Creme azedo", "Creme de leite 35%",
# 180
"1 colher de chá", "Manteiga", "Bebida de soja", "Bebida de amêndoas", "1 punhado", "Amêndoas", "Castanha-de-caju", "Nozes", "Amendoim torrado", "Pistaches",
# 190
"Sementes de girassol", "¼ xícara", "Sementes de chia", "Linhaça moída", "Pasta de amendoim", "Pasta de amêndoas", "Azeite de oliva", "Óleo de canola", "Homus", "Guacamole",
# 200
"1 fatia", "Pizza de queijo", "1 hambúrguer", "Hambúrguer", "1 cachorro-quente", "Cachorro-quente (pão e salsicha)", "Poutine", "6 nuggets", "Nuggets de frango", "6 pedaços",
# 210
"Sushi (maki)", "Poke de salmão", "Salada Caesar", "Sopa de legumes", "1 tigela grande", "Pho de carne", "Lámen (tigela)", "1 sanduíche", "Sanduíche de presunto e queijo", "Club sandwich",
# 220
"Sanduíche de queijo derretido", "1 wrap", "Wrap de frango", "Wrap de falafel", "1 prato", "Prato de shawarma de frango", "Espaguete à bolonhesa", "Lasanha à bolonhesa", "Macarrão com queijo", "Torta de carne com purê",
# 230
"Ensopado de carne", "Chili con carne", "Frango salteado com legumes", "Frango na manteiga", "Frango General Tso", "Arroz frito", "Pad thai", "1 burrito", "Burrito", "2 tacos",
# 240
"Tacos de carne", "1 quesadilla", "Quesadilla de queijo", "2 ovos", "Omelete simples", "Molho de tomate", "2 quadradinhos", "Chocolate amargo 70%", "Chocolate ao leite", "1 saquinho",
# 250
"Batata chips", "Tortilla chips", "Pretzels", "3 xícaras", "Pipoca natural", "1 bolinho de arroz", "Bolinho de arroz", "Mix de castanhas e frutas secas", "1 barra", "Barra de granola",
# 260
"Barra de proteína", "1 biscoito", "Cookie com gotas de chocolate", "Muffin", "1 rosquinha", "Rosquinha glaceada", "1 quadrado", "Brownie", "Torta de maçã", "Cheesecake",
# 270
"Sorvete", "Balas de goma", "1 lata", "Água com gás", "Café preto", "1 médio", "Café latte", "Chá sem açúcar", "Chocolate quente", "1 copo",
# 280
"Suco de laranja", "Suco de maçã", "Smoothie de frutas", "Refrigerante", "Refrigerante diet", "Limonada", "Energético", "1 garrafa", "Bebida esportiva", "Cerveja",
# 290
"Vinho tinto", "1,5 oz", "Destilado 40%", "Xarope de bordo", "Mel", "Açúcar branco", "Geleia", "Creme de avelã com cacau", "Ketchup", "Mostarda",
# 300
"Maionese", "Molho ranch", "Molho barbecue", "Molho de soja", "Salsa",
# 305 aliases
"couve kale", "batata doce", "batata", "batata-doce", "pimentao", "salada verde", "arroz integral", "macarrao integral", "pao integral", "flocos de milho",
# 315
"batata frita", "peito de frango", "carne moida", "hamburguer", "carne bovina moida", "cachorro-quente", "clara de ovo", "feijao vermelho", "grao-de-bico", "feijao preto",
# 325
"leite achocolatado", "leite integral", "leite de amendoas", "leite de soja", "bebida de soja", "nuggets de frango", "macarrao com queijo", "torta de carne", "barra de cereal", "milho inflado",
# 335
"pipoca", "barra de proteina", "sorvete", "cafe com leite", "coca zero",
# 340
"Quebec", "Canadá (federal)", "França", "Estados Unidos", "Ano-Novo", "Sexta-feira Santa", "Segunda-feira de Páscoa", "Dia Nacional dos Patriotas", "Festa Nacional de Quebec", "Dia do Canadá",
# 350
"Dia do Trabalho", "Ação de Graças", "Natal", "Dia da Rainha / Victoria", "Feriado cívico", "Verdade e Reconciliação", "Dia da Memória", "Dia seguinte ao Natal", "Vitória 1945", "Ascensão",
# 360
"Segunda-feira de Pentecostes", "Festa nacional", "Assunção", "Todos os Santos", "Armistício 1918", "Ano-Novo", "Dia de Martin Luther King Jr.", "Dia dos Presidentes", "Dia dos Caídos", "Juneteenth",
# 370
"Dia da Independência", "Dia do Trabalho", "Dia de Colombo", "Dia dos Veteranos", "Ação de Graças", "Natal", "Gibosa crescente", "Lua nova", "Lua crescente", "Quarto crescente",
# 380
"Lua minguante", "Quarto minguante", "Gibosa minguante", "Café da manhã", "Almoço", "Jantar", "Lanche", "Minha refeição", "Mulher", "Homem",
# 390
"Média dos dois", "Sedentário", "Leve (1–3 treinos)", "Moderada (3–5 treinos)", "Alta (6–7 treinos)", "Perder peso devagar", "Manter", "Ganhar músculo", "Ações", "ETF",
# 400
"Finanças", "Automóvel", "Design",
"Para widgets de Fitness no seu nível e calorias queimadas estimadas com o seu peso.",
"Suas metas do dia: os widgets de Nutrição contam o que ainda falta.",
"Seu orçamento e suas economias, usados pelos widgets de Orçamento e Finanças.",
"Sua atividade e sua meta, acompanhadas pelos widgets de Negócios.",
"O que você quer realizar, para widgets que te levam de volta a isso.",
"Seu programa e seu ritmo de trabalho.",
"Seu carro e a quilometragem, para acompanhar abastecimentos e manutenção.",
# 410
"Sua cidade, para o clima dos seus widgets.",
"Sua meta de água e um primeiro hábito para acompanhar.",
"Ganho de massa", "Perda de peso", "Definição", "Desempenho", "Manutenção", "Força", "Resistência", "Perder peso",
# 420
"Não binário", "Prefiro não responder", "Terminar o projeto Tessera", "Compras", "Cartão bancário", "Carregador de celular", "Confirmações de reserva", "Remédios", "Nécessaire", "Roupas",
# 430
"Adaptador de tomada", "Seguro viagem", "Passaporte", "portão %@", "assento %@", "Chegada · %@", "Partida · %@", "%@ · modelo", "Escolher um widget",
"Mostra um widget que você criou no Tessera ou um modelo do catálogo.",
# 440
"Widget", "Marcar uma tarefa", "Concluir um hábito", "Adicionar um copo de água", "Copos", "Iniciar uma sessão de Focus", "Minutos", "Parar a sessão de Focus", "Sessão concluída", "%@ minutos de concentração. Faça uma pausa.",
# 450
"Concluir série", "Alimento", "Contar", "Marcar uma prioridade", "Marcar uma tarefa do projeto", "Virar o cartão", "Avaliar o cartão", "Marcar um trabalho", "%@ × %@ kg", "Pronto",
# 460
"Pequeno", "Médio", "Grande", "Combinado · %@ widgets", "Um widget pequeno mostra um único widget.", "%@ não existe em pequeno.", "Escolha 1 widget, ou 2 para combinar.",
"%@ não existe em médio: adicione um 2º widget para combiná-los.",
"Para combinar 2 widgets, cada um precisa existir em pequeno.",
"Um widget médio combina no máximo 2 widgets.",
# 470
"Escolha de 1 a 4 widgets.",
"%@ não existe em grande: adicione outros widgets, até 4.",
"Para 2 widgets em grande, cada um precisa existir em médio: adicione um 3º ou 4º widget.",
"Para 3 widgets, um deles precisa existir em médio.",
"Esses widgets não cabem juntos em grande.",
"Para combinar 4 widgets, cada um precisa existir em pequeno.",
"Um widget grande combina no máximo 4 widgets.",
"Baixa", "Alta", "Nunca",
# 480
"Todo dia", "Dias úteis", "Toda semana", "por dia", "por semana", "a cada 2 semanas", "por ano", "Dias até", "Dias desde", "Saldo líquido",
# 490
"Férias",
]
write('pt-BR', T)
