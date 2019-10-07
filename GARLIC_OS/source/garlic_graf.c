/*------------------------------------------------------------------------------

	"garlic_graf.c" : fase 1 / programador G

	Funciones de gestión de las ventanas de texto (gráficas), para GARLIC 1.0

------------------------------------------------------------------------------*/
#include <nds.h>
#include <stdio.h>
#include <garlic_system.h>	// definición de funciones y variables de sistema
#include <garlic_font.h>	// definición gráfica de caracteres
#include <GARLIC_API.h>

/* definiciones para realizar cálculos relativos a la posición de los caracteres dentro de las ventanas gráficas, que pueden ser 4 o 16 */
#define NVENT 4 // número de ventanas totales
#define PPART 2 // número de ventanas horizontales o verticales			// (particiones de pantalla)
#define VCOLS 32 // columnas y filas de cualquier ventana
#define VFILS 24
#define PCOLS VCOLS * PPART // número de columnas totales
#define PFILS VFILS * PPART // número de filas totales


/* _gg_generarMarco: dibuja el marco de la ventana que se indica por parámetro*/
void _gg_generarMarco(int v)
{
	
}


/* _gg_iniGraf: inicializa el procesador gráfico A para GARLIC 1.0 */
/*	
	Resumen de tareas:
		1. modo 5, pantalla superior
		2. reservar banco mem A
		3. fondo 2 y 3 --> modo extended rotation
		4. fondo 3 + prioritario que fondo 2
		5. descomprimir fuente de letras en memoria de video
		6. copiar paleta colores memoria video
		7. marcos de ventanas en fondo 3
		8. reducir 50% fondos 2 y 3
*/
void _gg_iniGrafA()
{
	int i;
	int bg2, bg3;
	videoSetMode(MODE_5_2D);
	vramSetBankA(VRAM_A_MAIN_BG_0x06000000);
	bg2 = bgInit(2, BgType_ExRotation, BgSize_ER_512x512, 2, 0);
	bg3 = bgInit(3, BgType_ExRotation, BgSize_ER_512x512, 10, 0);
	bgSetPriority(bg2, 1);
	bgSetPriority(bg3, 0);
	decompress(garlic_fontTiles, bgGetGfxPtr(bg2), LZ77Vram);
	_gs_copiaMem(garlic_fontPal, BG_PALETTE, sizeof(garlic_fontPal));
	//for(i=0; i<NVENT; i++)
	//	_gg_generarMarco(i);
	bgSetScale(bg3,0x00000200,0x00000200);
	bgUpdate();
}



/* _gg_procesarFormato: copia los caracteres del string de formato sobre el
					  string resultante, pero identifica los códigos de formato
					  precedidos por '%' e inserta la representación ASCII de
					  los valores indicados por parámetro.
	Parámetros:
		formato	->	string con códigos de formato (ver descripción _gg_escribir);
		val1, val2	->	valores a transcribir, sean número de código ASCII (%c),
					un número natural (%d, %x) o un puntero a string (%s);
		resultado	->	mensaje resultante.
	Observación:
		Se supone que el string resultante tiene reservado espacio de memoria
		suficiente para albergar todo el mensaje, incluyendo los caracteres
		literales del formato y la transcripción a código ASCII de los valores.
*/
void _gg_procesarFormato(char *formato, unsigned int val1, unsigned int val2,
																char *resultado)
{
	
}


/* _gg_escribir: escribe una cadena de caracteres en la ventana indicada;
	Parámetros:
		formato	->	cadena de formato, terminada con centinela '\0';
					admite '\n' (salto de línea), '\t' (tabulador, 4 espacios)
					y códigos entre 32 y 159 (los 32 últimos son caracteres
					gráficos), además de códigos de formato %c, %d, %x y %s
					(max. 2 códigos por cadena)
		val1	->	valor a sustituir en primer código de formato, si existe
		val2	->	valor a sustituir en segundo código de formato, si existe
					- los valores pueden ser un código ASCII (%c), un valor
					  natural de 32 bits (%d, %x) o un puntero a string (%s)
		ventana	->	número de ventana (de 0 a 3)
*/
void _gg_escribir(char *formato, unsigned int val1, unsigned int val2, int ventana)
{

	
}
