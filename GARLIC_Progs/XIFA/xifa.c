#include <GARLIC_API.h>	

#define MAX_MENSAJES 10				// valores constantes usados en la rutina xifa. 
#define MAX_MATRICES 4
#define MAX_CODIGO 6
#define MAX_MENSAJE_CIFRADO 43

int _start(int arg) {
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
	char mensaje_cifrado[MAX_MENSAJE_CIFRADO];
	unsigned int pos, quo, mod, i, j, k;
	
	if (arg < 0) arg = 0;			// Limitar el valor máximo y 
	else if (arg > 3) arg = 3;		// el valor mínimo del argumento.
	
	GARLIC_divmod(GARLIC_random(), MAX_MENSAJES, &quo, &pos);
	for (; pos < MAX_MENSAJES; pos++) 
	{
		i = 0;
		k = 0;
		while (mensajes[pos][i] != '\0') 
		{
			j = 0;
			while ((mensajes[pos][i] != matrices_cifrado[arg][j]) && (matrices_cifrado[arg][j] != '\0')) 
			{
				j++;
			}
			if (mensajes[pos][i] == matrices_cifrado[arg][j]) 
			{
				GARLIC_divmod(j, MAX_CODIGO, &quo, &mod);
				mensaje_cifrado[k++] = codigo[mod];
				mensaje_cifrado[k++] = codigo[quo];
			}
			i++;
		}
		mensaje_cifrado[k] = '\0';
		GARLIC_printf("(%d)\t%s\n", GARLIC_pid(), mensaje_cifrado);
	}
	return 0;
}
