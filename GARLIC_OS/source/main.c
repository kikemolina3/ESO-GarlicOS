/*------------------------------------------------------------------------------

	"main.c" : fase 1 / programador G, P y M

------------------------------------------------------------------------------*/
#include <nds.h>
#include <garlic_system.h>	// definición de funciones y variables de sistema

extern int hola(int);		// función que simula la ejecución del proceso
extern int prnt(int);		// otra función (externa) de test correspondiente
							// a un proceso de usuario
extern int ccdl(int);		// se agrega dicha función de prueba (E. Molina)
extern int xifa(int);

extern int * punixTime;		// puntero a zona de memoria con el tiempo real

/* Inicializaciones generales del sistema Garlic */
//------------------------------------------------------------------------------
void inicializarSistema() {
//------------------------------------------------------------------------------
	int v;
	
	_gg_iniGrafA();			// inicializar procesador gráfico A
	for (v = 0; v < 4; v++)	// para todas las ventanas
		_gd_wbfs[v].pControl = 0;		// inicializar los buffers de ventana
	
	_gd_seed = *punixTime;	// inicializar semilla para números aleatorios con
	_gd_seed <<= 16;		// el valor de tiempo real UNIX, desplazado 16 bits
	
	irqInitHandler(_gp_IntrMain);	// instalar rutina principal interrupciones
	irqSet(IRQ_VBLANK, _gp_rsiVBL);	// instalar RSI de vertical Blank
	irqEnable(IRQ_VBLANK);			// activar interrupciones de vertical Blank
	REG_IME = IME_ENABLE;			// activar las interrupciones en general
	
	_gd_pcbs[0].keyName = 0x4C524147;	// "GARL"

	if (!_gm_initFS()) {
		_gg_escribir("ERROR: ¡no se puede inicializar el sistema de ficheros!", 0, 0, 0);
		exit(0);
	}
}


//------------------------------------------------------------------------------
int main(int argc, char **argv) {
//------------------------------------------------------------------------------

	intFunc start;
	inicializarSistema();
	
	_gg_escribir("********************************", 0, 0, 0);
	_gg_escribir("*                              *", 0, 0, 0);
	_gg_escribir("* Sistema Operativo GARLIC 1.0 *", 0, 0, 0);
	_gg_escribir("*                              *", 0, 0, 0);
	_gg_escribir("********************************", 0, 0, 0);
	_gg_escribir("*** Inicio fase 1_G_,_P_y_M\n", 0, 0, 0);
	
	_gg_escribir("*** Carga de programa CCDL.elf\n", 0, 0, 0);
	start = _gm_cargarPrograma("CCDL");
	if (start)
	{	_gg_escribir("*** Direccion de arranque :\n\t\t%p\n", (unsigned int)start, 0, 0);
		_gg_escribir("*** Pusle tecla \'START\' ::\n\n", 0, 0, 0);
		while(1) {
			_gp_WaitForVBlank();
			scanKeys();
			if (keysDown() & KEY_START) break;
		}
		_gp_crearProc(start, 5, "CCDL", 0);		// llamada al proceso CCDL scon argumento 0
	}else
	{
		_gg_escribir("*** Programa \"CCDL\" NO cargado\n", 0, 0, 0);
	}
	
	_gg_escribir("*** Carga de programa XIFA.elf\n", 0, 0, 0);
	start = _gm_cargarPrograma("XIFA");
	if (start)
	{	_gg_escribir("*** Direccion de arranque :\n\t\t%p\n", (unsigned int)start, 0, 0);
		_gg_escribir("*** Pusle tecla \'START\' ::\n\n", 0, 0, 0);
		while(1) {
			_gp_WaitForVBlank();
			scanKeys();
			if (keysDown() & KEY_START) break;
		}
		_gp_crearProc(start, 5, "XIFA", 2);		 //llamada al proceso XIFA con argumento 2
	}else
	{
		_gg_escribir("*** Programa \"XIFA\" NO cargado\n", 0, 0, 0);
	}
	
	_gg_escribir("*** Carga de programa DNIF.elf\n", 0, 0, 0);
	start = _gm_cargarPrograma("DNIF");
	if (start)
	{	_gg_escribir("*** Direccion de arranque :\n\t\t %p\n", (unsigned int)start, 0, 0);
		_gg_escribir("*** Pusle tecla \'START\' ::\n\n", 0, 0, 0);
		while(1) {
			_gp_WaitForVBlank();
			scanKeys();
			if (keysDown() & KEY_START) break;
		}
		_gp_crearProc(start, 5, "DNIF", 0);		// llamada al proceso PRNT con argumento 1
	}else
	{
		_gg_escribir("*** Programa \"DNIF\" NO cargado\n", 0, 0, 0);
	}
	
	while (_gp_numProc() > 1) {
		_gp_WaitForVBlank();
	}						// esperar a que terminen los procesos de usuario
	
	_gg_escribir("*** Final fase 1_G_,_P_y_M\n", 0, 0, 0);

	while (1) {
		_gp_WaitForVBlank();
	}							// parar el procesador en un bucle infinito
	
	return 0;
}
