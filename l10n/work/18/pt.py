from common import write
V = [
# 0
"Feito", "Prevista", "%@ do dia decorrido", "tarefa", "tarefas", "Depois: %@", "Nada urgente, aproveite", "25 min", "Hoje à noite", "tarefa concluída",
# 10
"tarefas concluídas", "O balanço do seu dia", "Nada previsto amanhã cedo", "Boa noite", "Leve um guarda-chuva (%@ %% de chuva)", "Tenha um bom dia", "treinos esta semana · sequência %@", "Próximo", "restam este mês · %@/dia", "Nenhuma aula prevista",
# 20
"Estudo esta semana", "Calculado a partir dos seus dados, no seu iPhone", "Crie seu primeiro treino no Tessera, no espaço Fitness.", "Adicione seu peso em “Minhas informações” para estimar as calorias queimadas.", "Em andamento · %@/%@ séries", "Treino feito hoje", "%@ · %@ séries", "%@ · %@ séries", "%@ · série %@/%@", "Descanso até %@",
# 30
"Toque para iniciar “%@”", "seu treino", "Conclua uma série para iniciar o descanso", "Descanso: pronto", "levantados esta semana", "Semana passada: %@ kg (%@)", "%@ kg esta semana", "Seus recordes aparecerão depois do seu primeiro treino.", "%@ · %@ rep.", "1RM estimado: %@ kg",
# 40
"%@: %@ kg", "Meta a definir no Tessera", "%@ esta semana", "Sequência: %@", "semanas", "%@/%@ treinos · sequência %@", "estimadas hoje", "Semana: %@ kcal", "Estimativa com base na duração dos treinos e no seu peso", "%@ kcal queimadas",
# 50
"%@ treinos em %@", "gastos este mês", "Orçamento mensal a definir no Tessera", "Gasto %@", "acima do orçamento", "ou seja, %@ por dia", "Gasto: %@ de %@", "Registre seus gastos no Tessera, no espaço Orçamento.", "%@ · %@ categorias", "Adicione suas contas a pagar no Tessera, no espaço Orçamento.",
# 60
"Próximos 30 dias: %@", "Crie uma meta de economia no Tessera, no espaço Orçamento.", "%@ por mês até %@", "Adicione suas contas e dívidas no Tessera, no espaço Orçamento.", "%@ em 30 dias", "ativos menos dívidas", "Ativos %@ · Dívidas %@", "Adicione suas assinaturas no Tessera, no espaço Orçamento.", "%@ · %@/ano", "assinatura",
# 70
"assinaturas", "Assinaturas %@/mês", "Crie seus gastos habituais (café, ônibus…) no Tessera, no espaço Orçamento.", "gasto hoje", "Resto do mês: %@", "Adicione seus investimentos no Tessera, no espaço Investimentos.", "%@%@ no total", "Hoje: %@", "Carteira %@", "em %@ · total %@",
# 80
"As variações aparecem para os investimentos cotados em tempo real.", "%@ em 24 h", "Sua posição: %@", "As cotações aparecem assim que houver conexão.", "Cotações: CoinGecko", "Os dados do mercado aparecem assim que houver conexão.", "capitalização · %@ em 24 h", "Dominância BTC", "Dominância ETH", "CoinGecko · %@",
# 90
"Mercado %@", "Registre sua primeira refeição no Tessera, no espaço Nutrição.", "Informe sua meta de calorias no Tessera para saber o que resta por refeição.", "consumidas hoje", "acima da meta", "restantes de %@", "Comido: %@ kcal", "+%@ kcal", "hoje · fibras %@ g", "de %@ · fibras %@ g",
# 100
"%@ g de proteínas hoje", "para atingir %@ g", "%@ g de proteínas restantes", "Nada registrado por enquanto", "alimento registrado", "alimentos registrados", "média por dia", "média · meta %@", "Últimos 30 dias: %@ kcal/dia", "registre uma refeição para continuar",
# 110
"refeição registrada hoje", "Sequência: %@", "Adicione favoritos no Tessera, no espaço Nutrição.", "hoje · toque para adicionar", "para %@", "incluindo %@ g de proteínas", "%@: %@ kcal", "restantes para a noite", "Escolha suas três prioridades no Tessera, no espaço Produtividade.", "Dia ganho",
# 120
"prioridades concluídas", "Prioridades %@/%@", "Crie um projeto e suas tarefas no Tessera, no espaço Produtividade.", "%@ tarefa%@ restante%@", "Adicione um prazo no Tessera, no espaço Produtividade.", "até %@", "Reta final", "Foco %@ esta semana", "Crie um contador no Tessera, no espaço Produtividade.", "faltam %@",
# 130
"no total", "Crie um hábito no Tessera para acompanhar sua sequência.", "feito hoje", "ainda não feito hoje", "Recorde: %@", "Crie seus hábitos no Tessera.", "check-ins esta semana", "Hábitos: %@ esta semana", "dos hábitos cumpridos em %@", "Hábitos: %@ este mês",
# 140
"Adicione suas aulas no Tessera, no espaço Estudos.", "Aula atual", "Em andamento · termina às %@", "%@ em andamento", "Adicione suas provas no Tessera, no espaço Estudos.", "Adicione seus trabalhos a entregar no Tessera, no espaço Estudos.", "a entregar", "Tudo entregue", "Adicione suas notas no Tessera, no espaço Estudos.", "média geral ponderada",
# 150
"Média %@%%", "Informe as datas do seu período de provas no Tessera, no espaço Estudos.", "%@ %@ restantes", "Termina em %@", "Período %@ · %@ d", "Crie seus cartões de revisão no Tessera, no espaço Estudos.", "Em dia", "Nenhum cartão para revisar por enquanto", "Próxima revisão %@", "Toque em “Resposta” para conferir",
# 160
"cartão para revisar", "cartões para revisar", "%@ cartões para revisar", "de %@ esta semana", "%@ da meta", "Estudo %@", "Horário · %@", "ontem", "em %@ dias", "há %@ dias",
# 170
"Hoje", "%@ d", "agora", "em %@ min", "em %@", "L", "N", "NE", "NO", "O",
# 180
"S", "SE", "SO", "baixo", "moderado", "alto", "muito alto", "extremo", "Último", "Adicione sua data de nascimento no Tessera, no espaço Minha vida.",
# 190
"%@ anos em %@ %@", "Feliz aniversário!", "%@ do seu ano em andamento", "para você fazer %@ anos", "%@ · %@ da semana", "Semana %@ · %@", "Nenhum feriado encontrado.", "Feriado", "Próximo feriado", "iluminada",
# 200
"Lua cheia %@", "Adicione sua viagem no Tessera, no espaço Viagem.", "de %@ · boa viagem!", "%@ · dia %@/%@", "é hora de partir!", "De %@ a %@", "Adicione seu voo no Tessera, no espaço Viagem.", "Terminal %@", "Portão %@", "Assento %@",
# 210
"Adicione sua hospedagem no Tessera, no espaço Viagem.", "Chegada %@ às %@", "Saída %@ às %@", "Reserva", "Escolha a cidade de destino no espaço Viagem.", "O clima aparece assim que houver conexão.", "Agora no local · previsão da estadia 7 dias antes", "Previsão durante a sua estadia", "%@%@ h em relação a aqui", "mesmo horário daqui",
# 220
"Seu destino usa a sua moeda: nada a converter.", "As taxas de câmbio aparecem assim que houver conexão.", "para %@", "Taxa de referência BCE · %@ · Frankfurter", "último dia", "de viagem, partida %@", "Planeje suas atividades no Tessera, no espaço Viagem.", "Escolha sua cidade no Tessera para ver o clima.", "Os horários do sol chegam com a próxima atualização do clima.", "Nascer do sol · %@",
# 230
"Pôr do sol · %@", "Nascer do sol amanhã", "Duração do dia: %@ · %@", "Pôr do sol", "Nascer do sol", "O risco de chuva chega com a próxima atualização do clima.", "Possíveis pancadas de chuva nas próximas 12 h", "Sem chuva prevista nas próximas 12 h", "Probabilidade de precipitação · Open-Meteo.com", "vento %@",
# 240
"rajadas %@", "UV %@ · %@", "Máximo do dia", "Vento %@ km/h", "Sensação", "UV", "Chuva hoje", "Sensação %@ · ↑%@ ↓%@", "%@%% de chuva", "Toque para desbloquear este widget",
# 250
"Entitlements", "nenhum grupo", "nenhum", "assinatura: %@ · perfil: %@", "Inativo", "Inativo (nenhum grupo)", "Ativo (grupo da instalação)", "Cobalto", "Âmbar", "Lilás",
# 260
"Oliva", "Ardósia", "Noite", "Tinta", "Bordô", "Névoa", "Branco", "Segue o modo claro ou escuro", "Sempre luminoso", "Sempre escuro",
# 270
"Preto, branco, nada mais", "Translúcido e luminoso", "Um degradê de azul-noite a turquesa", "Serifa e reflexos dourados", "Elegante", "Digital", "Tela de cristal líquido", "Papel quente e fonte arredondada", "Futurista", "Neon ciano sobre noite profunda",
# 280
"Números grandes, com serifa", "Tipografia", "Sua cor em tela cheia", "Moderno", "Limpo, suave, ícones em pílulas", "Cartão", "O conteúdo sobre um cartão", "Formas redondas, tons suaves", "Compacto", "Mais infos, menos espaço",
# 290
"Liquid Glass", "Vidro líquido e reflexos", "Grafite, prata, filete fino", "Sua cor em degradê vivo", "Brilhos rosa sobre fundo preto", "Serifa, papel e maiúsculas", "Revista", "Um número grande, como uma capa", "Cartões pequenos, tudo num relance", "Painel",
# 300
"Ousado", "Números enormes, cor cheia", "Dados", "Grade, mono e curvas", "Luxo", "Preto e amarelo neon, energia", "Azul-marinho, sóbrio e alinhado", "Sua cor sobre preto, linhas de tela", "Azul de arquiteto e grade", "Planta",
# 310
"Cores de confeito", "Papel creme e tinta", "Borda grossa, preto sobre branco", "Brutalista", "Carbono", "Fibra escura e relevo", "Rosa e azul retrofuturista", "Vapor", "Lousa e giz", "Pálido, leve, quase translúcido",
# 320
"Meu widget", "Seu último widget salvo no Tessera, sem nenhum ajuste.", "Série %@/%@",
]
write('pt-BR', V)
