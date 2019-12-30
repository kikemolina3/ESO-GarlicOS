#include <GARLIC_API.h>		// inclusi�n del API para simular un proceso

void _start(int arg) {
	
	char * mensajes[10] = {"el 20 de diciembre montar� el �rbol de navidad.",
						"el 9 de enero del 2018 se entrega la pr�ctica de la asignatura.",
						"quiero ir al cine a ver la pel�cula 1917",
						"eL 21 de junio es el cumplea�os de mi hermana",
						"no entiendo porque hay gente a la que no le gusta blade runner 2049",
						"este verano he le�do 3 libros",
						"querr�a sacar un 10 en alguna pr�ctica de programaci�n",
						"este viernes tengo cena de navidad a las 22 horas",
						"joker estar� nominada a 8 oscars",
						"el mes de agosto tiene 31 d�as"};
	char * matriz_cifrado[4] = {"0fqbizw1xm8ern2gtskpu3jdo7hi4v9cl6a5",
								"til6b2ugdm4rqvkfy5nspc8z37ohj9wa1ex0",
								"o1segf20haydrbzp4nq98ctk3xi75wju6mvl",
								"1gr4hde2av9m8pinkzbyuf6t5gxs3owlq7c0"};
	char codigo[6] = "ADFGVX";
 	char mensaje_cifrado[108];
	unsigned int quo, mod, pos, i, j, k;
	int fi=0;
	
	if (arg < 0) arg = 0;			// Limitar valor m�ximo del argumento
	else if (arg > 3) arg = 3;		// Limitar valor m�nimo del argumento
	
	GARLIC_divmod(GARLIC_random(), 10, &quo, &pos);
	for (; pos<10; pos++) {
		k=0;
		i=0;
		while (mensajes[pos][i]!='\0') {
			j=0;
			while ((!fi) && (matriz_cifrado[arg][j]!='\0')) {
				if (mensajes[pos][i]==matriz_cifrado[arg][j]) fi=1;
				else j++;
			}
			GARLIC_divmod(j, 10, &quo, &mod);
			mensaje_cifrado[k++]=codigo[mod];
			mensaje_cifrado[k++]=codigo[quo];
			i++;
		}
		mensaje_cifrado[k]='\0';
		GARLIC_printf("PID (%d)%s\t",GARLIC_pid, mensaje_cifrado);
	}
}