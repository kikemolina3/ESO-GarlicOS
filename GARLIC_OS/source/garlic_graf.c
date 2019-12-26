/*------------------------------------------------------------------------------

	"garlic_graf.c" : fase 1 / programador G

	Funciones de gestión de las ventanas de texto (gráficas), para GARLIC 1.0

------------------------------------------------------------------------------*/
#include <nds.h>
#include <garlic_system.h>	// definición de funciones y variables de sistema
#include <garlic_font.h>	// definición gráfica de caracteres


/* definiciones para realizar cálculos relativos a la posición de los caracteres dentro de las ventanas gráficas, que pueden ser 4 o 16 */
#define NVENT 4 // número de ventanas totales
#define PPART 2 // número de ventanas horizontales o verticales			// (particiones de pantalla)
#define VCOLS 32 // columnas y filas de cualquier ventana
#define VFILS 24
#define PCOLS VCOLS * PPART // número de columnas totales
#define PFILS VFILS * PPART // número de filas totales
#define B_MARCO 0x06004000


/* _gg_generarMarco: dibuja el marco de la ventana que se indica por parámetro */
void _gg_generarMarco(int v)
{
	unsigned int coc, res;
	int i;
	coc=v/PPART;
	res=v%PPART;
	unsigned int despl = 2*(PCOLS*VFILS*coc + VCOLS*res);
	_gg_fijarBaldosa(B_MARCO, despl, 103);					//esquina izquierda superior
	despl += 2;
	for(i=0; i<VCOLS-2; i++)								//fila superior (excto. esquinas)
	{
		_gg_fijarBaldosa(B_MARCO, despl, 99);
		despl += 2;
	}
	_gg_fijarBaldosa(B_MARCO, despl, 102);					//esquina derecha superior	
	for(i=0; i<VFILS-2; i++)								//laterales derecho & izquierdo
	{
		despl = despl + 2 + 2*(PCOLS-VCOLS);
		_gg_fijarBaldosa(B_MARCO, despl, 96);
		despl = despl + 2*(VCOLS-1);
		_gg_fijarBaldosa(B_MARCO, despl, 98);
	}
	despl = despl + 2 + 2*(PCOLS-VCOLS); 
	_gg_fijarBaldosa(B_MARCO, despl, 100);					//esquina inferior izquierda
	despl += 2;
	for(i=0; i<VCOLS-2; i++)								//fila inferior (excto. esquinas)
	{
		_gg_fijarBaldosa(B_MARCO, despl, 97);
		despl += 2;
	}
	_gg_fijarBaldosa(B_MARCO, despl, 101);					//esquina inferior derecha


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
	bg2 = bgInit(2, BgType_ExRotation, BgSize_ER_512x512, 4, 0);
	bg3 = bgInit(3, BgType_ExRotation, BgSize_ER_512x512, 8, 0);
	bgSetPriority(bg2, 1);
	bgSetPriority(bg3, 0);
	decompress(garlic_fontTiles, bgGetGfxPtr(bg2), LZ77Vram);
	_gs_copiaMem(garlic_fontPal, BG_PALETTE, sizeof(garlic_fontPal));
	for(i=0; i<NVENT; i++)
		_gg_generarMarco(i);
	bgSetScale(bg3,0x00000200,0x00000200);
	bgSetScale(bg2,0x00000200,0x00000200);
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
void _gg_procesarFormato(char *formato, unsigned int val1, unsigned int val2,      			/// NECESITA REFRACTORING
																char *resultado)
{
	
int cont_f=0, cont_r=0, j=0;
	char used1=0, used2=0, next;
	char * e;
	unsigned int val=0;
	char temp_int[12], temp_hex[9];
	while(cont_f<VCOLS*3 && formato[cont_f]!='\0')
	{
		if(formato[cont_f]=='%' && (!used1 || !used2))
		{
			next = formato[cont_f+1];
			if(next == 'd' || next == 'x' || next == 's' || next == 'c')
			{
					if(!used1)
					{
						val = val1;
						used1 = 1;
					}
					else
					{
						val = val2;
						used2 = 1;
					}
			}
			switch(next)
			{	case 'd':
					_gs_num2str_dec(temp_int, 12, val);
					j = 0;
					while(temp_int[j] == ' ')		j++;
					while(temp_int[j] != '\0')
					{
						resultado[cont_r] = temp_int[j];
						j++;
						cont_r++;
					}
					cont_f += 2;
					break;
				case 'x':
					_gs_num2str_hex(temp_hex, 9, val);
					j = 0;
					while(temp_hex[j] != '\0')
					{
						resultado[cont_r] = temp_hex[j];
						j++;
						cont_r++;
					}
					cont_f += 2;
					break;
				case 's':
					e = (char*) val;
					while(e[j] != '\0' && cont_f < 99)
						{
							resultado[cont_r] = e[j];
							j++;
							cont_r++;
						}
					cont_f += 2;
					break;
				case 'c':
					e = (char*) val;
					resultado[cont_r] = (unsigned int) e;
					cont_r++;	cont_f += 2;
					break;
				case '%':
					resultado[cont_r] = formato[cont_f];
					cont_r++;	cont_f += 2;
					break;  
				default:
					resultado[cont_r] = formato[cont_f];
					cont_r++;	cont_f++;
			}	
		}
		else
		{
			resultado[cont_r] = formato[cont_f];
			cont_r++;	cont_f++;
		}
		
	}
	resultado[cont_r]='\0';
	return;
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

	char res[VCOLS*3 + 1];
	
	_gg_procesarFormato(formato, val1, val2, res);
	
	int fila_actual = (_gd_wbfs[ventana].pControl & 0xFFFF0000) >> 16;
	int num_char = _gd_wbfs[ventana].pControl & 0xFFFF;
	int i;
	
	// STRING TO BUFFER & IMPRESSION
	for(i = 0; res[i] != '\0'; i++)
	{
		if(res[i] == 9)			//horizontal tab
		{ 
			while(num_char % 4 != 0)
			{
				_gd_wbfs[ventana].pChars[num_char] = ' '; 
				num_char++;
				_gd_wbfs[ventana].pControl += 1;				
			}
		}
		else if(res[i] == 10)		//line feed
		{
			while(num_char != VCOLS)
			{
				_gd_wbfs[ventana].pChars[num_char] = ' '; 
				num_char++;
				_gd_wbfs[ventana].pControl += 1;				
			}
		}
		else
		{
			_gd_wbfs[ventana].pChars[num_char] = res[i];
			num_char++;
			_gd_wbfs[ventana].pControl += 1;
		}
		if(num_char == VCOLS)
		{
			swiWaitForVBlank();
			if(fila_actual == VFILS)
			{
				_gg_desplazar(ventana);
				fila_actual = VFILS - 1;
			}
			_gg_escribirLinea(ventana, fila_actual, num_char);
			if(fila_actual != VFILS)
				fila_actual++;
			num_char = 0;
			_gd_wbfs[ventana].pControl = 0;
			if(res[i+1] == ' ')			//elimina espacio linea inicial
				i++;
		}
	}
	
	//salvar estado gd_wbufs
	int aux = fila_actual << 16;
	aux = aux + num_char;
	_gd_wbfs[ventana].pControl = aux;
	
}
