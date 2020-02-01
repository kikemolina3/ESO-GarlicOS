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

#include <garlic_system.h>	// definición de funciones y variables de sistema

#define INI_MEM 0x01002000		// dirección inicial de memoria para programas
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


/* _gm_initFS: inicializa el sistema de ficheros, devolviendo un valor booleano
					para indiciar si dicha inicialización ha tenido éxito; */
int _gm_initFS()
{
	return nitroFSInit(NULL);	// inicializar sistema de ficheros NITRO
}


/* _gm_listaProgs: devuelve una lista con los nombres en clave de todos
			los programas que se encuentran en el directorio "Programas".
			 Se considera que un fichero es un programa si su nombre tiene
			8 caracteres y termina con ".elf"; se devuelven sólo los
			4 primeros caracteres de los programas (nombre en clave).
			 El resultado es un vector de strings (paso por referencia) y
			el número de programas detectados */
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
				segmentos de programa a partir de una posición de memoria libre,
				efectuando la reubicación de las referencias a los símbolos del
				programa, según el desplazamiento del código y los datos en la
				memoria destino;
	Parámetros:
		zocalo	->	índice del zócalo que indexará el proceso del programa
		keyName ->	vector de 4 caracteres con el nombre en clave del programa
	Resultado:
		!= 0	->	dirección de inicio del programa (intFunc)
		== 0	->	no se ha podido cargar el programa
*/
intFunc _gm_cargarPrograma(int zocalo, char *keyName)
{
	FILE* prog;
	Elf32_Ehdr *header;
	Elf32_Phdr *segment;
	int *buffAux,size,puntero[2],pos,numSeg=0,hay_espacio=1,offset,adresaFinal=0;
	char path[21]="/Programas/";
	unsigned char ph_type;
    strcat(path, keyName);
	strcat(path, ".elf");
	prog = fopen(path, "rb");
	
	
	
	if(prog){
		fseek(prog,0,SEEK_END);						//LEEMOS TODO EL FICHERO Y LO GUARDAMOS EN BUFFAUX
		size=ftell(prog);
		buffAux=malloc(size);
		fseek(prog,0,SEEK_SET);
		fread(buffAux,1,size,prog);
		//buffAux contiene todo el fichero ELF
		
		header=malloc(sizeof(Elf32_Ehdr));
		if(header)
		{
			fseek(prog,0,SEEK_SET);						//COGEMOS CABECERA
			fread(header,1,sizeof(Elf32_Ehdr),prog);
			offset=header->e_entry - 0x8000;
		
			
			
			segment= malloc(sizeof(Elf32_Phdr) * header->e_phnum);
			if(segment)
			{
				while((numSeg<header->e_phnum) && (hay_espacio))
				{ 	
					//COGEMOS SEGMENTO
					pos=header->e_phoff+(numSeg*header->e_phentsize);	
					fseek(prog,pos,SEEK_SET);
					fread(&segment[numSeg],1,sizeof(Elf32_Phdr),prog);
					
					if(segment[numSeg].p_type==1){				
						
						if(segment[numSeg].p_flags == 5){
							ph_type=0;
						}else{
							ph_type=1;
						}
						//Reservamos memoria
						
						puntero[numSeg]=(int) _gm_reservarMem(zocalo,segment[numSeg].p_memsz,ph_type);
						if(puntero[numSeg] != 0) //HAY ESPACIO
						{
							if(segment[numSeg].p_flags == 5){ adresaFinal = puntero[numSeg] + offset;} //SI ES DE CODIGO GUARDAMOS DIR INICIAL
							segment[numSeg].p_offset +=(int) buffAux;
							_gs_copiaMem((const void *)segment[numSeg].p_offset,(void *) puntero[numSeg],segment[numSeg].p_filesz);
							
						}else{
							hay_espacio=0;
							adresaFinal=0;
							if(numSeg>0) {_gm_liberarMem(zocalo);}
						}
						
					}
					
					
					numSeg++;
				}
				
				
				if(hay_espacio!=0)
				{
					if(header->e_phnum==1){
							_gm_reubicar((char*)buffAux,(unsigned int)segment[0].p_paddr,(unsigned int *) puntero[0],0,0);
					}else{
							_gm_reubicar((char*)buffAux,(unsigned int)segment[0].p_paddr,(unsigned int *) puntero[0],(unsigned int ) segment[1].p_paddr,(unsigned int *) puntero[1]);
					}
				}
				free(segment);
				fclose(prog);
			}
			free(header);
		}
		free(buffAux);
	}
	
	return ((intFunc) adresaFinal);
}

