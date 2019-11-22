/*------------------------------------------------------------------------------

	"garlic_mem.c" : fase 1 / programador M

	Funciones de carga de un fichero ejecutable en formato ELF, para GARLIC 1.0

------------------------------------------------------------------------------*/
#include <nds.h>
#include <filesystem.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dirent.h>
#include <garlic_system.h>	// definición de funciones y variables de sistema

#define INI_MEM 0x01002000		// dirección inicial de memoria para programas

int punteroLibre=INI_MEM;		// direccion de memoria a primera pos. libre 

//* ESTRUCTURAS PARA MANEJAR LA GESTION DE MEMORIA *//

/*CABECERA FICHERO ELF */
typedef struct{
	unsigned char e_ident[EI_NIDENT]; 	//0-15
	unsigned short e_type;				
	unsigned short e_machine;			//18-19
	unsigned long int e_version;
	unsigned long int e_entry;			//24-27	
	unsigned long int e_phoff;			
	unsigned long int e_shoff;			//32-35
	unsigned long int e_flags;			
	unsigned short e_ehsize;			//40-41
	unsigned short e_phentsize;			
	unsigned short e_phnum;				//44-45
	unsigned short e_shentsize;			
	unsigned short e_shnum;				//48-49
	unsigned short e_shstrndx;			
}Elf32_Ehdr;

/*TABLA DE SEGMENTOS*/
typedef struct{
	unsigned long int p_type;
	unsigned long int p_offset;
	unsigned long int p_vaddr;
	unsigned long int p_paddr;
	unsigned long int p_filesz;
	unsigned long int p_memsz;
	unsigned long int p_flags;
	unsigned long int p_align;
}Elf32_Phdr;

/*TABLA DE SECCIONES*/
typedef struct{
	unsigned long int sh_name;
	unsigned long int sh_type;
	unsigned long int sh_flags;
	unsigned long int sh_addr;
	unsigned long int sh_offset;
	unsigned long int sh_size;
	unsigned long int sh_link;
	unsigned long int sh_info;
	unsigned long int sh_addralign;
	unsigned long int sh_entsize;
}Elf32_Shdr;

/*REUBICADORES*/
typedef struct{
	unsigned long int r_offset;
	unsigned long int r_info;
}Elf32_Rel;



/* _gm_initFS: inicializa el sistema de ficheros, devolviendo un valor booleano
					para indiciar si dicha inicialización ha tenido éxito; */
int _gm_initFS()
{
	return nitroFSInit(NULL);	// inicializar sistema de ficheros NITRO
}



/* _gm_cargarPrograma: busca un fichero de nombre "(keyName).elf" dentro del
					directorio "/Programas/" del sistema de ficheros, y
					carga los segmentos de programa a partir de una posición de
					memoria libre, efectuando la reubicación de las referencias
					a los símbolos del programa, según el desplazamiento del
					código en la memoria destino;
	Parámetros:
		keyName ->	vector de 4 caracteres con el nombre en clave del programa
	Resultado:
		!= 0	->	dirección de inicio del programa (intFunc)
		== 0	->	no se ha podido cargar el programa
*/
intFunc _gm_cargarPrograma(char *keyName)
{
	FILE* prog;
	Elf32_Ehdr header;
	Elf32_Phdr segment;
	int *buffAux,size,*puntero,pos,numSeg;
	char path[21]="/Programas/";
	header.e_entry=0;
    strcat(path, keyName);
	strcat(path, ".elf");
	prog = fopen(path, "rb");
	
	
	if(prog){
		fseek(prog,0,SEEK_END);
		size=ftell(prog);
		//printf("%i\n",size);
		buffAux=malloc(size);
		fseek(prog,0,SEEK_SET);
		fread(buffAux,1,size,prog);
		//buffAux contiene todo el fichero ELF
		fclose(prog);
		//Cogemos los datos de la cabecera que necesitamos
		header.e_entry= buffAux[6];
		header.e_phoff= buffAux[7];
		header.e_shoff= buffAux[8];
		header.e_phentsize= buffAux[10] && 0xF0;
		header.e_phnum= buffAux[11] && 0x0F;
		header.e_shentsize= buffAux[7] ;
		header.e_shnum= buffAux[12] && 0x0F;
		puntero=malloc(header.e_phnum*sizeof(int));
		
		//Recorremos los segmentos y cargamos los tipos LOAD
		for(numSeg=0;numSeg<header.e_phnum;numSeg++){
			pos=(header.e_phoff/4)+(numSeg*header.e_phentsize);
			segment.p_type= buffAux[pos];
			if(segment.p_type==1){
				//printf("Hay segmento a cargar en memoria\n");
				
				//Cogemos datos del segmento 
				segment.p_offset=buffAux[pos+1];
				segment.p_paddr=buffAux[pos+3];
				segment.p_filesz=buffAux[pos+4];
				segment.p_memsz=buffAux[pos+5];
				segment.p_flags=buffAux[pos+6];
				
				//Cargamos en memoria el segmento
				puntero[numSeg]=punteroLibre;
				//printf("%i",puntero);
				if(numSeg==0){
				header.e_entry=puntero[numSeg];
				//printf("%li\n",header.e_entry);
				}
				segment.p_offset +=(int) buffAux;
				_gs_copiaMem((const void *)segment.p_offset,(void *) puntero[numSeg],segment.p_filesz);
				punteroLibre+=segment.p_memsz;
				while(punteroLibre%4!=0){
					punteroLibre+=1;
				}
				//Reubicamos las posiciones sensibles
				_gm_reubicar((char*)buffAux,(unsigned int)segment.p_paddr,(unsigned int *) puntero[numSeg]);
				
			}
		}
		
		free(buffAux);
		free(puntero);
	}
	
	return ((intFunc) header.e_entry);
	
}

