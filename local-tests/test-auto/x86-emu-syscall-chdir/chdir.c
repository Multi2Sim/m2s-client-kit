#include <unistd.h>
#include <stdio.h>

int main()
{
	char path[200];

	// Current directory
	getcwd(path, sizeof path);
	printf("%s\n", path);

	// Change to subdirectory 'subdir'
	chdir("subdir");

	// Child directory
	getcwd(path, sizeof path);
	printf("%s\n", path);

	// Go back
	chdir("..");

	// Back to parent
	getcwd(path, sizeof path);
	printf("%s\n", path);
}

