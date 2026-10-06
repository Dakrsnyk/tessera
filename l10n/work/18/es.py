from common import write
V = [
# 0
"Hecho", "Prevista", "%@ del día transcurrido", "tarea", "tareas", "Después: %@", "Nada urgente, disfruta", "25 min", "Esta noche", "tarea hecha",
# 10
"tareas hechas", "El balance de tu día", "Nada previsto temprano mañana", "Buenas noches", "Lleva paraguas (%@ %% de lluvia)", "Que tengas un buen día", "entrenamientos esta semana · racha %@", "Próxima", "quedan este mes · %@/día", "Sin clases previstas",
# 20
"Estudio esta semana", "Calculado con tus datos, en tu iPhone", "Crea tu primer entrenamiento en el espacio Fitness de Tessera.", "Añade tu peso en «Mis datos» para estimar las calorías quemadas.", "En curso · %@/%@ series", "Entrenamiento hecho hoy", "%@ · %@ series", "%@ · %@ series", "%@ · serie %@/%@", "Descanso hasta las %@",
# 30
"Toca para empezar «%@»", "tu entrenamiento", "Completa una serie para iniciar el descanso", "Descanso: listo", "levantados esta semana", "Semana pasada: %@ kg (%@)", "%@ kg esta semana", "Tus récords aparecerán después de tu primer entrenamiento.", "%@ · %@ rep.", "1RM estimado: %@ kg",
# 40
"%@: %@ kg", "Define una meta en Tessera", "%@ esta semana", "Racha: %@", "semanas", "%@/%@ entrenamientos · racha %@", "estimadas hoy", "Semana: %@ kcal", "Estimación según la duración de los entrenamientos y tu peso", "%@ kcal quemadas",
# 50
"%@ entrenamientos en %@", "gastados este mes", "Define un presupuesto mensual en Tessera", "Gastado %@", "por encima del presupuesto", "es decir, %@ al día", "Gastado: %@ de %@", "Anota tus gastos en el espacio Presupuesto de Tessera.", "%@ · %@ categorías", "Añade tus facturas en el espacio Presupuesto de Tessera.",
# 60
"Próximos 30 días: %@", "Crea una meta de ahorro en el espacio Presupuesto de Tessera.", "%@ al mes hasta el %@", "Añade tus cuentas y deudas en el espacio Presupuesto de Tessera.", "%@ en 30 días", "activos menos deudas", "Activos %@ · Deudas %@", "Añade tus suscripciones en el espacio Presupuesto de Tessera.", "%@ · %@/año", "suscripción",
# 70
"suscripciones", "Suscripciones %@/mes", "Crea tus gastos habituales (café, bus…) en el espacio Presupuesto de Tessera.", "gastado hoy", "Resto del mes: %@", "Añade tus inversiones en el espacio Inversiones de Tessera.", "%@%@ en total", "Hoy: %@", "Cartera %@", "en %@ · total %@",
# 80
"Las variaciones aparecen para las inversiones con cotización en vivo.", "%@ en 24 h", "Tu posición: %@", "Las cotizaciones aparecen en cuanto haya conexión.", "Cotizaciones: CoinGecko", "Los datos del mercado aparecen en cuanto haya conexión.", "capitalización · %@ en 24 h", "Dominancia BTC", "Dominancia ETH", "CoinGecko · %@",
# 90
"Mercado %@", "Anota tu primera comida en el espacio Nutrición de Tessera.", "Indica tu objetivo de calorías en Tessera para saber cuánto te queda por comida.", "consumidas hoy", "por encima del objetivo", "restantes de %@", "Comido: %@ kcal", "+%@ kcal", "hoy · fibra %@ g", "de %@ · fibra %@ g",
# 100
"%@ g de proteínas hoy", "para llegar a %@ g", "%@ g de proteínas restantes", "Nada anotado por ahora", "alimento anotado", "alimentos anotados", "promedio diario", "promedio · objetivo %@", "Últimos 30 días: %@ kcal/día", "anota una comida para continuar",
# 110
"comida anotada hoy", "Racha: %@", "Añade favoritos en el espacio Nutrición de Tessera.", "hoy · toca para añadir", "para %@", "de las cuales %@ g de proteínas", "%@: %@ kcal", "restantes para la noche", "Elige tus tres prioridades en el espacio Productividad de Tessera.", "Día ganado",
# 120
"prioridades hechas", "Prioridades %@/%@", "Crea un proyecto y sus tareas en el espacio Productividad de Tessera.", "%@ tarea%@ pendiente%@", "Añade un vencimiento en el espacio Productividad de Tessera.", "hasta %@", "Recta final", "Focus %@ esta semana", "Crea un contador en el espacio Productividad de Tessera.", "faltan %@",
# 130
"en total", "Crea un hábito en Tessera para seguir tu racha.", "hecho hoy", "aún no hecho hoy", "Récord: %@", "Crea tus hábitos en Tessera.", "registros esta semana", "Hábitos: %@ esta semana", "de los hábitos cumplidos en %@", "Hábitos: %@ este mes",
# 140
"Añade tus clases en el espacio Estudios de Tessera.", "Clase actual", "En curso · termina a las %@", "%@ en curso", "Añade tus exámenes en el espacio Estudios de Tessera.", "Añade tus trabajos por entregar en el espacio Estudios de Tessera.", "por entregar", "Todo entregado", "Añade tus notas en el espacio Estudios de Tessera.", "promedio general ponderado",
# 150
"Promedio %@ %%", "Indica las fechas de tu periodo de exámenes en el espacio Estudios de Tessera.", "%@ %@ restantes", "Termina el %@", "Periodo %@ · %@ d", "Crea tus fichas de repaso en el espacio Estudios de Tessera.", "Al día", "Ninguna ficha por repasar por ahora", "Próximo repaso %@", "Toca «Respuesta» para comprobar",
# 160
"ficha por repasar", "fichas por repasar", "%@ fichas por repasar", "de %@ esta semana", "%@ del objetivo", "Estudio %@", "Horario · %@", "ayer", "en %@ días", "hace %@ días",
# 170
"Hoy", "%@ d", "ahora", "en %@ min", "en %@", "E", "N", "NE", "NO", "O",
# 180
"S", "SE", "SO", "bajo", "moderado", "alto", "muy alto", "extremo", "Último", "Añade tu fecha de nacimiento en el espacio Mi vida de Tessera.",
# 190
"Cumples %@ en %@ %@", "¡Feliz cumpleaños!", "%@ de tu año en curso", "para que cumplas %@ años", "%@ · %@ de la semana", "Semana %@ · %@", "No se encontraron festivos.", "Festivo", "Próximo festivo", "iluminada",
# 200
"Luna llena %@", "Añade tu viaje en el espacio Viajes de Tessera.", "de %@ · ¡buen viaje!", "%@ · día %@/%@", "¡es hora de salir!", "Del %@ al %@", "Añade tu vuelo en el espacio Viajes de Tessera.", "Terminal %@", "Puerta %@", "Asiento %@",
# 210
"Añade tu alojamiento en el espacio Viajes de Tessera.", "Llegada %@ a las %@", "Salida %@ a las %@", "Reserva", "Elige la ciudad de destino en el espacio Viajes.", "El clima aparece en cuanto haya conexión.", "Ahora en el lugar · pronóstico del viaje 7 días antes", "Pronóstico durante tu viaje", "%@%@ h respecto a aquí", "misma hora que aquí",
# 220
"Tu destino usa tu moneda: nada que convertir.", "Los tipos de cambio aparecen en cuanto haya conexión.", "por %@", "Tipo de referencia BCE · %@ · Frankfurter", "último día", "de viaje, salida %@", "Planifica tus actividades en el espacio Viajes de Tessera.", "Elige tu ciudad en Tessera para ver el clima.", "Las horas del sol llegan con la próxima actualización del clima.", "Amanecer · %@",
# 230
"Atardecer · %@", "Amanecer mañana", "Duración del día: %@ · %@", "Atardecer", "Amanecer", "La probabilidad de lluvia llega con la próxima actualización del clima.", "Posibles chubascos en las próximas 12 h", "Sin lluvia prevista en las próximas 12 h", "Probabilidad de precipitación · Open-Meteo.com", "viento %@",
# 240
"ráfagas %@", "UV %@ · %@", "Máximo del día", "Viento %@ km/h", "Sensación", "UV", "Lluvia hoy", "Sensación %@ · ↑%@ ↓%@", "%@ %% de lluvia", "Toca para desbloquear este widget",
# 250
"Entitlements", "ningún grupo", "ninguno", "firma: %@ · perfil: %@", "Inactivo", "Inactivo (ningún grupo)", "Activo (grupo de la instalación)", "Cobalto", "Ámbar", "Lila",
# 260
"Oliva", "Pizarra", "Noche", "Tinta", "Burdeos", "Bruma", "Blanco", "Sigue el modo claro u oscuro", "Siempre luminoso", "Siempre oscuro",
# 270
"Negro, blanco, nada más", "Translúcido y luminoso", "Un degradado de azul noche a turquesa", "Serif y destellos dorados", "Elegante", "Digital", "Pantalla de cristal líquido", "Papel cálido y tipografía redondeada", "Futurista", "Neón cian sobre noche profunda",
# 280
"Números grandes, en serif", "Tipografía", "Tu color a pleno fondo", "Moderno", "Limpio, suave, iconos en círculos", "Tarjeta", "El contenido sobre una tarjeta", "Formas redondas, tonos suaves", "Compacto", "Más info, menos espacio",
# 290
"Liquid Glass", "Cristal líquido y reflejos", "Grafito, plata, borde fino", "Tu color en degradado vivo", "Destellos rosas sobre negro", "Serif, papel y mayúsculas", "Revista", "Un número grande, como una portada", "Tarjetas pequeñas, todo de un vistazo", "Panel",
# 300
"Atrevido", "Números enormes, color pleno", "Datos", "Cuadrícula, mono y curvas", "Lujo", "Negro y amarillo fluorescente, energía", "Azul marino, sobrio y alineado", "Tu color sobre negro, líneas de pantalla", "Azul de arquitecto y cuadrícula", "Plano",
# 310
"Colores de caramelo", "Papel crema y tinta", "Borde grueso, negro sobre blanco", "Brutalista", "Carbono", "Fibra oscura y relieve", "Rosa y azul retrofuturista", "Vapor", "Pizarra negra y tiza", "Pálido, ligero, casi translúcido",
# 320
"Mi widget", "Tu último widget guardado en Tessera, sin ningún ajuste.", "Serie %@/%@",
]
write('es', V)
