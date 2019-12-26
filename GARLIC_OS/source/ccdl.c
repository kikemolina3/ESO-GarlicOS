/****************************************************/
/*		Algoritmo de Cuatro Cuadrados De 			*/
/*				Lagrange (ccdl)						*/
/*					--------						*/
/*			Autor: Enrique Molina Giménez			*/
/****************************************************/

#include <GARLIC_API.h>

/*
//Función que retorna un número aleatorio natural entre 0 y a//
*/
int alea(int a)
{
	unsigned int coc, res;
	GARLIC_divmod(GARLIC_random(), a+1 ,&coc ,&res);
	return res;
}
/*
//Función que calcula la raíz cuadrada aproximada del entero a//
*/
int raiz(int a)
{
	int i;
	float x = a;
	for(i = 0; i < 10; i++)
		x = (x*x + a) / (2*x);
	return (int)x;
	
}
/*
//Función que retorna el resultado de a elevado a b//
*/
int pot(int a, int b)
{
	int i;
	int x = 1;
	for(i=0;i<b;i++)
		x *= a;
	return x;
}

/****************************************************************************/
/*	Algoritmo principal. Actúa bajo los siguientes criterios:
	1. Genera un numero aleatorio entre 0 y 25^(arg+2), de tal manera que:
		si arg=0 --> nro[0...625]
		si arg=1 --> nro[0...15.625]
		si arg=2 --> nro[0...390.625]
		si arg=3 --> nro[0...9.765.625]
	2. Para dicho numero se calculan tantas sumas de cuatro cuadrados como 
	iteraciones determine la siguiente fórmula: nro_iter=2^(6-2*arg)
		si arg=0 --> nro_iter=64
		si arg=1 --> nro_iter=16
		si arg=2 --> nro_iter=4
		si arg=3 --> nro_iter=1
	3. Se imprimen los resultados
****************************************************************************/
int ccdl(int arg)
{
	if (arg < 0) arg = 0;			// limitar valor máximo y 
	else if (arg > 3) arg = 3;		// valor mínimo del argumento
	
	GARLIC_printf("-- Programa CCDL  -  PID (%d) --\n", GARLIC_pid());
	int num, cota_sup, nro_iter, cont=0;
	cota_sup = pot(25, arg+2);
   	num = alea(cota_sup);
    GARLIC_printf("El numero es: %d \nComb. sumas de cuadrados:\n", num);
   	nro_iter = pot(2, 6 - 2*arg);
	int a, b, c, d;
	while(cont < nro_iter)
	{
		a = alea( raiz(num) );
		b = alea( raiz(num - a*a) );
		c = alea( raiz(num - a*a - b*b) );
		d = alea( raiz(num - a*a - b*b - c*c) );
		if((a*a + b*b + c*c + d*d) == num)
        {
            cont++;
            GARLIC_printf("%d\t \t%d\t \t", a, b);
			GARLIC_printf("%d\t \t%d\n", c, d);
		}
	}
	GARLIC_printf("El numero era: %d \n", num);
	return 0;
}
