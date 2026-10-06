from common import write
T = [
# 0
"Mantén las caderas en el suelo.",
"Empuja suavemente con las manos para levantar el pecho.",
"Inhala al subir, exhala al bajar.",
"Hasta sentir una tensión agradable en el abdomen, sin dolor de espalda.",
"Codos ligeramente flexionados.",
"Hombros abajo, lejos de las orejas.",
"Despegar las caderas.",
"Forzar el arco de la espalda.",
"Frutas", "Verduras",
# 10
"Almidones", "Lácteos", "Nueces y semillas", "Platillos", "Snacks", "Bebidas", "Salsas y azúcares",
"1 manzana mediana", "Manzana", "1 plátano",
# 20
"Plátano", "1 naranja", "Naranja", "1 clementina", "Clementina", "1 taza", "Fresas", "Arándanos", "Frambuesas", "Uvas",
# 30
"1 pera", "Pera", "1 durazno", "Durazno", "1 ciruela", "Ciruela", "Cerezas", "1 kiwi", "Kiwi", "Mango",
# 40
"Piña", "1 rebanada", "Sandía", "Melón cantalupo", "Toronja", "½ toronja", "Aguacate", "½ aguacate", "1 taza", "Compota de manzana sin azúcar",
# 50
"1 caja pequeña", "Pasas", "3 dátiles", "Dátiles", "Brócoli", "1 zanahoria", "Zanahoria", "1 tomate", "Tomate", "Pepino",
# 60
"½ pepino", "Lechuga", "1 taza cruda", "Espinacas", "Col rizada (kale)", "1 pimiento", "Pimiento", "1 cebolla", "Cebolla", "Judías verdes",
# 70
"Coliflor", "Repollo", "Coles de Bruselas", "6 espárragos", "Espárragos", "1 rama", "Apio", "Berenjena", "1 betabel", "Betabel",
# 80
"Champiñones", "Calabacín", "1 mazorca", "Maíz", "Guisantes", "½ taza", "Edamame", "1 mediana", "Papa cocida", "Batata cocida",
# 90
"1 tazón", "Ensalada verde (sin aderezo)", "Arroz blanco cocido", "Arroz integral cocido", "Pasta cocida", "Pasta integral cocida", "Fideos de arroz cocidos", "Quinoa cocida", "Cuscús cocido", "Avena en hojuelas",
# 100
"½ taza en seco", "Avena cocida con agua", "Pan blanco", "Pan integral", "1 trozo", "Baguette", "1 bagel", "Bagel", "1 pita", "Pan pita",
# 110
"1 muffin", "Muffin inglés", "1 tortilla", "Tortilla de trigo", "1 croissant", "Croissant", "1 hotcake", "Hotcake", "1 waffle", "Waffle",
# 120
"Cereal de maíz", "Granola", "5 galletas saladas", "Galletas saladas", "1 porción mediana", "Papas fritas", "Pechuga de pollo cocida", "1 muslo", "Muslo de pollo cocido", "Pechuga de pavo cocida",
# 130
"Carne molida semimagra cocida", "1 bistec", "Bistec de solomillo cocido", "Lomo de cerdo cocido", "Jamón", "2 rebanadas", "Tocino cocido", "1 salchicha", "Salchicha de cerdo cocida", "Salchicha ahumada (hot dog)",
# 140
"1 filete", "Salmón cocido", "Bacalao cocido", "Tilapia cocida", "Atún enlatado (en agua)", "1 lata", "Sardinas enlatadas", "Camarones cocidos", "1 huevo grande", "Huevo",
# 150
"1 clara", "Clara de huevo", "Tofu firme", "Lentejas cocidas", "Garbanzos cocidos", "Frijoles negros cocidos", "Frijoles rojos cocidos", "1 scoop", "Proteína en polvo (suero de leche)", "Leche 2 %",
# 160
"Leche 3,25 %", "Leche descremada", "Leche con chocolate", "Yogur griego natural 0 %", "¾ taza", "Yogur griego natural 2 %", "1 envase", "Yogur con frutas", "Kéfir natural", "Cheddar",
# 170
"Mozzarella", "Queso suizo", "Feta", "1 cucharada", "Parmesano", "Queso cottage", "2 cucharadas", "Queso crema", "Crema agria", "Crema para batir 35 %",
# 180
"1 cucharadita", "Mantequilla", "Bebida de soya", "Bebida de almendra", "1 puñado", "Almendras", "Nueces de la India", "Nueces", "Cacahuates tostados", "Pistachos",
# 190
"Semillas de girasol", "¼ taza", "Semillas de chía", "Linaza molida", "Mantequilla de cacahuate", "Mantequilla de almendra", "Aceite de oliva", "Aceite de canola", "Hummus", "Guacamole",
# 200
"1 rebanada", "Pizza de queso", "1 hamburguesa", "Hamburguesa", "1 hot dog", "Hot dog (pan y salchicha)", "Poutine", "6 nuggets", "Nuggets de pollo", "6 piezas",
# 210
"Sushi (maki)", "Poke bowl de salmón", "Ensalada César", "Sopa de verduras", "1 tazón grande", "Pho de res", "Ramen (tazón)", "1 sándwich", "Sándwich de jamón y queso", "Club sándwich",
# 220
"Sándwich de queso derretido", "1 wrap", "Wrap de pollo", "Wrap de falafel", "1 plato", "Plato de shawarma de pollo", "Espagueti con salsa de carne", "Lasaña de carne", "Macarrones con queso", "Pastel de carne y puré",
# 230
"Estofado de res", "Chili con carne", "Salteado de pollo y verduras", "Pollo a la mantequilla", "Pollo General Tso", "Arroz frito", "Pad thai", "1 burrito", "Burrito", "2 tacos",
# 240
"Tacos de res", "1 quesadilla", "Quesadilla de queso", "2 huevos", "Omelette natural", "Salsa de tomate", "2 cuadritos", "Chocolate amargo 70 %", "Chocolate con leche", "1 bolsa pequeña",
# 250
"Papas fritas de bolsa", "Totopos", "Pretzels", "3 tazas", "Palomitas naturales", "1 galleta de arroz", "Galleta de arroz", "Mezcla de frutos secos", "1 barra", "Barra de granola",
# 260
"Barra de proteína", "1 galleta", "Galleta con chispas de chocolate", "Muffin", "1 dona", "Dona glaseada", "1 cuadro", "Brownie", "Pay de manzana", "Cheesecake",
# 270
"Helado", "Gomitas", "1 lata", "Agua con gas", "Café negro", "1 mediano", "Café latte", "Té sin azúcar", "Chocolate caliente", "1 vaso",
# 280
"Jugo de naranja", "Jugo de manzana", "Licuado de frutas", "Refresco", "Refresco dietético", "Limonada", "Bebida energética", "1 botella", "Bebida deportiva", "Cerveza",
# 290
"Vino tinto", "1,5 oz", "Licor 40 %", "Jarabe de arce", "Miel", "Azúcar blanca", "Mermelada", "Crema de chocolate y avellanas", "Kétchup", "Mostaza",
# 300
"Mayonesa", "Aderezo ranch", "Salsa BBQ", "Salsa de soya", "Salsa",
# 305 aliases
"col rizada", "batata", "papa", "camote", "morron", "ensalada verde", "arroz integral", "pasta integral", "pan integral", "cereal de maiz",
# 315
"papas fritas", "pechuga de pollo", "carne molida", "bistec molido", "carne picada", "perro caliente", "clara de huevo", "frijoles rojos", "garbanzo", "frijoles negros",
# 325
"leche con chocolate", "leche entera", "leche de almendra", "leche de soja", "leche de soya", "nuggets de pollo", "macarrones con queso", "pastel de papa", "barra de cereal", "maiz inflado",
# 335
"palomitas", "barra de proteina", "helado", "cafe con leche", "coca cero",
# 340
"Quebec", "Canadá (federal)", "Francia", "Estados Unidos", "Año Nuevo", "Viernes Santo", "Lunes de Pascua", "Día nacional de los Patriotas", "Fiesta Nacional de Quebec", "Día de Canadá",
# 350
"Día del Trabajo", "Acción de Gracias", "Navidad", "Día de la Reina / Victoria", "Feriado cívico", "Verdad y Reconciliación", "Día del Recuerdo", "Día después de Navidad", "Victoria 1945", "Ascensión",
# 360
"Lunes de Pentecostés", "Fiesta nacional", "Asunción", "Todos los Santos", "Armisticio 1918", "Año Nuevo", "Día de Martin Luther King Jr.", "Día de los Presidentes", "Día de los Caídos", "Juneteenth",
# 370
"Día de la Independencia", "Día del Trabajo", "Día de Colón", "Día de los Veteranos", "Acción de Gracias", "Navidad", "Luna gibosa creciente", "Luna nueva", "Luna creciente", "Cuarto creciente",
# 380
"Luna menguante", "Cuarto menguante", "Luna gibosa menguante", "Desayuno", "Almuerzo", "Cena", "Snack", "Mi comida", "Mujer", "Hombre",
# 390
"Promedio de ambos", "Sedentario", "Ligera (1–3 entrenamientos)", "Moderada (3–5 entrenamientos)", "Alta (6–7 entrenamientos)", "Perder peso poco a poco", "Mantener", "Ganar músculo", "Acciones", "ETF",
# 400
"Finanzas", "Automóvil", "Diseño",
"Para widgets de Fitness a tu nivel y calorías quemadas estimadas con tu peso.",
"Tus objetivos del día: los widgets de Nutrición cuentan lo que te queda.",
"Tu presupuesto y tus ahorros, usados por los widgets de Presupuesto y Finanzas.",
"Tu actividad y tu objetivo, seguidos por los widgets de Negocio.",
"Lo que quieres lograr, para widgets que te ayuden a conseguirlo.",
"Tu programa y tu ritmo de trabajo.",
"Tu auto y su kilometraje, para seguir las cargas de combustible y el mantenimiento.",
# 410
"Tu ciudad, para el clima de tus widgets.",
"Tu objetivo de agua y un primer hábito que seguir.",
"Aumento de masa", "Pérdida de peso", "Definición", "Rendimiento", "Mantenimiento", "Fuerza", "Resistencia", "Perder peso",
# 420
"No binario", "Prefiero no responder", "Terminar el proyecto Tessera", "Compras", "Tarjeta bancaria", "Cargador del teléfono", "Confirmaciones de reserva", "Medicamentos", "Neceser", "Ropa",
# 430
"Adaptador de enchufe", "Seguro de viaje", "Pasaporte", "puerta %@", "asiento %@", "Llegada · %@", "Salida · %@", "%@ · plantilla", "Elegir un widget",
"Muestra un widget que creaste en Tessera o una plantilla del catálogo.",
# 440
"Widget", "Marcar una tarea", "Completar un hábito", "Añadir un vaso de agua", "Vasos", "Iniciar una sesión de Focus", "Minutos", "Detener la sesión de Focus", "Sesión terminada", "%@ minutos de concentración. Toma un descanso.",
# 450
"Completar la serie", "Alimento", "Contar", "Marcar una prioridad", "Marcar una tarea del proyecto", "Voltear la tarjeta", "Calificar la tarjeta", "Marcar una tarea escolar", "%@ × %@ kg", "Listo",
# 460
"Pequeño", "Mediano", "Grande", "Combinado · %@ widgets", "Un widget pequeño muestra un solo widget.", "%@ no existe en pequeño.", "Elige 1 widget, o 2 para combinarlos.",
"%@ no existe en mediano: añade un 2.º widget para combinarlos.",
"Para combinar 2 widgets, cada uno debe existir en pequeño.",
"Un widget mediano combina 2 widgets como máximo.",
# 470
"Elige de 1 a 4 widgets.",
"%@ no existe en grande: añade más widgets, hasta 4.",
"Para 2 widgets en grande, cada uno debe existir en mediano: añade un 3.º o un 4.º widget.",
"Para 3 widgets, uno de ellos debe existir en mediano.",
"Estos widgets no caben juntos en grande.",
"Para combinar 4 widgets, cada uno debe existir en pequeño.",
"Un widget grande combina 4 widgets como máximo.",
"Baja", "Alta", "Nunca",
# 480
"Todos los días", "Entre semana", "Cada semana", "por día", "por semana", "cada 2 semanas", "por año", "Días para", "Días desde", "Saldo neto",
# 490
"Vacaciones",
]
write('es', T)
