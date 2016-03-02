#include <stdio.h>
#include <unistd.h>
#include <assert.h>
#include <fcntl.h>

int main()
{
	printf("Creating lseek.txt\n");
	int fd = open("lseek.txt", O_RDWR | O_CREAT | O_TRUNC, 0660);
	assert(fd > 0);

	printf("Writing 2 characters\n");
	int err = write(fd, "ab", 2);
	assert(err == 2);

	printf("Position at the beginning\n");
	err = lseek(fd, 0, SEEK_SET);
	assert(err == 0);

	printf("Overwrite first letter\n");
	err = write(fd, "c", 1);
	assert(err == 1);

	printf("Position at the end\n");
	err = lseek(fd, 0, SEEK_END);
	assert(err == 2);

	printf("Append letter\n");
	err = write(fd, "d", 1);
	assert(err == 1);

	printf("Go to the beginning\n");
	err = lseek(fd, 0, SEEK_SET);
	assert(err == 0);

	printf("Read it all\n");
	char buf[3];
	err = read(fd, buf, 3);
	assert(err == 3);
	assert(buf[0] == 'c');
	assert(buf[1] == 'b');
	assert(buf[2] == 'd');

	printf("Get current position\n");
	err = lseek(fd, 0, SEEK_CUR);
	assert(err == 3);

	printf("Closing and removing lseek.txt\n");
	close(fd);
	unlink("lseek.txt");
	return 0;
}

