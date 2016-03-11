#include <assert.h>
#include <stdio.h>
#include <unistd.h>
#include <sys/stat.h>
#include <sys/types.h>

int main()
{
	// Path to text for
	char *path = "test.txt";

	// System call 'stat'
	printf("System call 'stat' ... ");
	struct stat buf;
	int err = stat(path, &buf);
	assert(err == 0);
	assert(buf.st_size == 5);
	printf("ok\n");

	// System call 'lstat'
	printf("System call 'lstat' ... ");
	err = lstat(path, &buf);
	assert(err == 0);
	assert(buf.st_size == 5);
	printf("ok\n");

	return 0;
}

