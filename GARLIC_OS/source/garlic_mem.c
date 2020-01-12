/*------------------------------------------------------------------------------

	"garlic_mem.c" : fase 2 / programador M

	Funciones de carga de un fichero ejecutable en formato ELF, para GARLIC 2.0

------------------------------------------------------------------------------*/
#include <nds.h>
#include <filesystem.h>
#include <dirent.h>			// para struct dirent, etc.
#include <stdio.h>			// para fopen(), fread(), etc.
#include <stdlib.h>			// para malloc(), etc.
#include <string.h>			// para strcat(), memcpy(), etc.

#include <garlic_system.h>	// definici�n de funciones y variables de sistema

#define INI_MEM 0x01002000		// direcci�n inicial de memoria para programas
#define EI_NIDENT 16

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
					para indiciar si dicha inicializaci�n ha tenido �xito; */
int _gm_initFS()
{
	return nitroFSInit(NULL);	// inicializar sistema de ficheros NITRO
}


/* _gm_listaProgs: devuelve una lista con los nombres en clave de todos
			los programas que se encuentran en el directorio "Programas".
			 Se considera que un fichero es un programa si su nombre tiene
			8 caracteres y termina con ".elf"; se devuelven s�lo los
			4 primeros caracteres de los programas (nombre en clave).
			 El resultado es un vector de strings (paso por referencia) y
			el n�mero de programas detectados */
int _gm_listaProgs(char* progs[])
{
	DIR *dir;
	struct dirent *ent;
	char *nombre;
	char *tipo;
	int num_progs=0;
	dir = opendir("/Programas/");
	
	if(dir!=NULL){
		while((ent = readdir (dir)) != NULL)
		{
			if((strcmp(ent->d_name, ".")!=0) && (strcmp(ent->d_name, "..")!=0)){
				if(strlen(ent->d_name)==8){
					strcat(ent->d_name, ".");
					nombre=strtok(ent->d_name, ".");
					tipo=strtok(NULL, ".");
					if(strcmp(tipo,"elf")==0){
						progs[num_progs]=(char * ) malloc(5);
						strcpy(progs[num_progs],nombre);
						strcat(progs[num_progs],"\0");
						num_progs+=1;
					}
				}
			
			}
		
		}
	
	}
	closedir(dir);
	return num_progs;
}


/* _gm_cargarPrograma: busca un fichero de nombre "(keyName).elf" dentro del
				directorio "/Programas/" del sistema de ficheros, y carga los
				segmentos de programa a partir de una posici�n de memoria libre,
				efectuando la reubicaci�n de las referencias a los s�mbolos del
				programa, seg�n el desplazamiento del c�digo y los datos en la
				memoria destino;
	Par�metros:
		zocalo	->	�ndice del z�calo que indexar� el proceso del programa
		keyName ->	vector de 4 caracteres con el nombre en clave del programa
	Resultado:
		!= 0	->	direcci�n de inicio del programa (intFunc)
		== 0	->	no se ha podido cargar el programa
*/
intFunc _gm_cargarPrograma(int zocalo, char *keyName)
{
	FILE* prog;
	Elf32_Ehdr header;
	Elf32_Phdr *segment;
	int *buffAux,size,puntero[2],pos,numSeg=0,hay_espacio=1,offset;
	char path[21]="/Programas/";
	unsigned char ph_type;
	header.e_entry=0;
    strcat(path, keyName);
	strcat(path, ".elf");
	prog = fopen(path, "rb");
	
	
	if(prog){
		fseek(prog,0,SEEK_END);
		size=ftell(prog);
		buffAux=malloc(size);
		fseek(prog,0,SEEK_SET);
		fread(buffAux,1,size,prog);
		//buffAux contiene todo el fichero ELF
		fclose(prog);
		//Cogemos los datos de la cabecera que necesitamos
		header.e_entry= buffAux[6];
		offset = header.e_entry - 0x8000;
		header.e_phoff= buffAux[7];
		header.e_shoff= buffAux[8];
		header.e_phentsize= buffAux[10] & 0xF0;
		header.e_phnum= buffAux[11] & 0x0F;
		header.e_shentsize= buffAux[7] ;
		header.e_shnum= buffAux[12] & 0x0F;
		
		
		segment= malloc(header.e_phentsize*header.e_phnum);
		while((numSeg<header.e_phnum) && (hay_espacio)){
			pos=(header.e_phoff/4)+(numSeg*header.e_phentsize);
			segment[numSeg].p_type= buffAux[pos];
			if(segment[numSeg].p_type==1){
				
				//Cogemos datos del segmento 
				segment[numSeg].p_offset=buffAux[pos+1];
				segment[numSeg].p_paddr=buffAux[pos+3];
				segment[numSeg].p_filesz=buffAux[pos+4];
				segment[numSeg].p_memsz=buffAux[pos+5];
				segment[numSeg].p_flags=buffAux[pos+6];
				
				if(segment[numSeg].p_flags == 5){
					ph_type=0;
				}else{
					ph_type=1;
				}
				//Reservamos memoria
				puntero[numSeg]=(int) _gm_reservarMem(zocalo,segment[numSeg].p_memsz,ph_type);
				printf("%i",puntero[numSeg]);
				if(puntero[numSeg] != 0) //HAY ESPACIO
				{
					if(segment[numSeg].p_flags == 5){	//SI ES DE CODIGO GUARDAMOS DIR INICIAL
						header.e_entry = puntero[numSeg] + offset;
					}
					segment[numSeg].p_offset +=(int) buffAux;
					_gs_copiaMem((const void *)segment[numSeg].p_offset,(void *) puntero[numSeg],segment[numSeg].p_filesz);
					
				}else{
					hay_espacio=0;
					header.e_entry=0;
				}
				
			}
			
			
			numSeg++;
		}
		
		
		if(hay_espacio)
		{
			if(header.e_phnum==1){
					_gm_reubicar((char*)buffAux,(unsigned int)segment[0].p_paddr,(unsigned int *) puntero[0],0,0);
			}else{
					_gm_reubicar((char*)buffAux,(unsigned int)segment[0].p_paddr,(unsigned int *) puntero[0],(unsigned int ) segment[1].p_paddr,(unsigned int *) puntero[1]);
			}
		}
		free(buffAux);
		//free(puntero);
	}
	
	return ((intFunc) header.e_entry);
}

