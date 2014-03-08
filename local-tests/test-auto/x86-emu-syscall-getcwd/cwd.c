#include <unistd.h>
#include <stdio.h>

int main()
{
	char path[200];
	getcwd(path, sizeof path);
	printf("%s\n", path);
	return 0;
}

