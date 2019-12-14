/*------------------------------------------------------------------------------

	"main.c" : fase 1 / programador P

	Programa de prueba de creación y multiplexación de procesos en GARLIC 1.0,
	pero sin cargar procesos en memoria ni utilizar llamadas a _gg_escribir().

------------------------------------------------------------------------------*/
#include <nds.h>
#include <stdio.h>

#include <garlic_system.h>	// definición de funciones y variables de sistema

#include <GARLIC_API.h>		// inclusión del API para simular un proceso

#define MAX_MENSAJES 10
#define MAX_MATRICES 4
#define MAX_CODIGO 6

int hola(int);				// función que simula la ejecución del proceso
int xifa(int);

extern int * punixTime;		// puntero a zona de memoria con el tiempo real


/* Inicializaciones generales del sistema Garlic */
//------------------------------------------------------------------------------
void inicializarSistema() {
//------------------------------------------------------------------------------

	consoleDemoInit();		// inicializar consola, sólo para esta simulación
	
	_gd_seed = *punixTime;	// inicializar semilla para números aleatorios con
	_gd_seed <<= 16;		// el valor de tiempo real UNIX, desplazado 16 bits
	
	irqInitHandler(_gp_IntrMain);	// instalar rutina principal interrupciones
	irqSet(IRQ_VBLANK, _gp_rsiVBL);	// instalar RSI de vertical Blank
	irqEnable(IRQ_VBLANK);			// activar interrupciones de vertical Blank
	REG_IME = IME_ENABLE;			// activar las interrupciones en general
	
	_gd_pcbs[0].keyName = 0x4C524147;	// "GARL"
}


//------------------------------------------------------------------------------
int main(int argc, char **argv) {
//------------------------------------------------------------------------------
	
	inicializarSistema();
	
	printf("********************************");
	printf("*                              *");
	printf("* Sistema Operativo GARLIC 1.0 *");
	printf("*                              *");
	printf("********************************");
	printf("*** Inicio fase 1_P\n");
	
	_gp_crearProc(hola, 7, "HOLA", 1);
	_gp_crearProc(xifa, 9, "XIFA", 0);
	_gp_crearProc(hola, 8, "HOLA", 2);
	
	
	while (_gp_numProc() > 1) {
		_gp_WaitForVBlank();
		printf("*** Test %d:%d\n", _gd_tickCount, _gp_numProc());
	}						// esperar a que terminen los procesos de usuario

	printf("*** Final fase 1_P\n");

	while (1) {
		_gp_WaitForVBlank();
	}							// parar el procesador en un bucle infinito
	
	return 0;
}


/* Proceso de prueba, con llamadas a las funciones del API del sistema Garlic */
//------------------------------------------------------------------------------
int hola(int arg) {
//------------------------------------------------------------------------------
	unsigned int i, j, iter;
	
	if (arg < 0) arg = 0;			// limitar valor máximo y 
	else if (arg > 3) arg = 3;		// valor mínimo del argumento
	
									// esccribir mensaje inicial
	GARLIC_printf("-- Programa HOLA  -  PID (%d) --\n", GARLIC_pid());
	
	j = 1;							// j = cálculo de 10 elevado a arg
	for (i = 0; i < arg; i++)
		j *= 10;
						// cálculo aleatorio del número de iteraciones 'iter'
	GARLIC_divmod(GARLIC_random(), j, &i, &iter);
	iter++;							// asegurar que hay al menos una iteración
	
	for (i = 0; i < iter; i++)		// escribir mensajes
		GARLIC_printf("(%d)\t%d: Hello world!\n", GARLIC_pid(), i);

	return 0;
}

int xifa(int arg) {
	char * mensajes[MAX_MENSAJES] = { "hola",
										"Todo bien",
										"esta noche he quedado",
										"ayer estudie 8 horas",
										"el examen fue muy bien",
										"me gusta mucho leer",
										"quiero ir a ver 1917",
										"estamos casi en 2020",
										"me aburro si no estudio",
										"se me rompio el ordenador" };
	char * matrices_cifrado[MAX_MATRICES] = { "0fqbizw1xm8ern2gtskpu3jdo7hy4v9cl6a5",
											"til6b2ugdm4rqvkfy5nspc8z37ohj9wa1ex0",
											"147regimntabcdfhjklopqsuvwxyz0235689",
											"8p3dln1t4oah7kbc5zju6wgmxsvir29ey0fq" };
	char codigo[MAX_CODIGO] = { "ADFGVX" };
	char mensaje_cifrado[42];
	unsigned int pos, quo, mod, i, j, k;
	
	GARLIC_divmod(GARLIC_random(), MAX_MENSAJES, &quo, &pos);
	for (; pos < MAX_MENSAJES; pos++) {
		i = 0;
		k = 0;
		while (mensajes[pos][i] != '\0') {
			j = 0;
			while ((mensajes[pos][i] != matrices_cifrado[arg][j]) && (matrices_cifrado[arg][j] != '\0')) {
				j++;
			}
			if (mensajes[pos][i] == matrices_cifrado[arg][j]) {
				GARLIC_divmod(j, MAX_CODIGO, &quo, &mod);
				mensaje_cifrado[k++] = codigo[mod];
				mensaje_cifrado[k++] = codigo[quo];
			}
			i++;
		}
		GARLIC_printf("PID (%d)\t%s\n", GARLIC_pid(), mensaje_cifrado);
	}
	return 0;
}
