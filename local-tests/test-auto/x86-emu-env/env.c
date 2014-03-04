#include <stdio.h>
#include <stdlib.h>

extern char **environ;

int main(int argc, char **argv)
{
	if (argc != 2)
		exit(1);
	char *var = argv[1];
	char *value = getenv(var);
	printf("%s = %s\n", var, value);
}

