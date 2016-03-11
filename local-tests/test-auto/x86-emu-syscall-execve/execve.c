#include <assert.h>
#include <stdio.h>
#include <stdlib.h>

int main()
{
	// Invoke 'execve()' through 'system()' function
	system("echo Hello");
	return 0;
}

