/****************************************************/
/*		Algoritmo de Cuatro Cuadrados De 			*/
/*				Lagrange (ccdl)						*/
/*					--------						*/
/*			Autor: Enrique Molina Giménez			*/
/****************************************************/

#include <GARLIC_API.h>
#include <math.h>

int alea(int a)
{
	unsigned int coc,res;
	GARLIC_divmod(GARLIC_random(),a,&coc,&res);
	res++;
	return res;
}

int ccdl(int arg)
{
	GARLIC_printf("-- Programa CCDL  -  PID (%d) --\n", GARLIC_pid());
	unsigned int num, exp, nro_iter, cont=0;
	exp=arg+1;
   	num=pow(alea(25),exp);
    GARLIC_printf("El numero es: %d \n",num);
   	nro_iter=pow(2,6-2*arg);
	unsigned int a,b,c,d;
	while(cont<nro_iter)
	{
		a=alea(sqrt(num)-3);
		a=a*a;
		b=alea(sqrt(num-a)-2);
		b=b*b;
		c=alea(sqrt(num-a-b)-1);
		c=c*c;
		d=alea(sqrt(num-a-b-c));
		d=d*d;
		if(a+b+c+d==num)
        {
            cont++;
            GARLIC_printf("%d\t%d\t",(unsigned int)sqrt(a),(unsigned int)sqrt(b));
			GARLIC_printf("%d\t%d\n",(unsigned int)sqrt(c),(unsigned int)sqrt(d));
		}
	}
	return 0;
}
