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

//* ESTRUCTURAS PARA MANEJAR LA GESTION DE MEMORIA *//

/*CABECERA FICHERO ELF */
typedef struct{
	unsigned char e_ident[EI_NIDENT];
	unsigned short e_type;
	unsigned short e_machine;
	unsigned long int e_version;
	unsigned long int e_entry;
	unsigned long int e_phoff;
	unsigned long int e_shoff;
	unsigned long int e_flags;
	unsigned short e_ehsize;
	unsigned short e_phentsize;
	unsigned short e_phnum;
	unsigned short e_shentsize;
	unsigned short e_shnum;
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
	Elf32_Phdr *buffSegment;
	Elf32_Shdr *buffSection;
	int  bytesSegmentos,bytesSecciones;
	char path[21]="/Programas/";

    strcat(path, keyName);
	strcat(path, ".elf");
	prog = fopen(path, "rb");
	
	if (prog)
	{
		fread(&header,1,sizeof(header),prog);
		
		bytesSegmentos=header.e_phnum*header.e_phentsize;
		bytesSecciones=header.e_shnum*header.e_shentsize;
		//printf("%i,%i\n",bytesSegmentos,bytesSecciones);
		buffSegment=malloc(bytesSegmentos);
		buffSection=malloc(bytesSecciones);
		
		fseek(prog,header.e_phoff,SEEK_SET);
		fread(buffSegment,1,bytesSegmentos,prog);
		
		fseek(prog,header.e_shoff,SEEK_SET);
		fread(buffSection,1,bytesSecciones,prog);
		fclose(prog);
		
	}
	return ((intFunc) header.e_entry);
}

