#include <fcntl.h>
#include <stdio.h>
#include <string.h>

int main()
{
	// Create file 'open.txt' and write into it
	char *file_name = "open.txt";
	int fd = open(file_name, O_CREAT | O_WRONLY, 0660);
	char *text = "This is some text to write.\n";
	size_t count = write(fd, text, strlen(text));
	printf("%d bytes written\n", count);
	close(fd);

	// Append content to the file
	fd = open(file_name, O_APPEND | O_WRONLY);
	text = "Second line\n";
	count = write(fd, text, strlen(text));
	printf("%d bytes written\n", count);
	close(fd);

	// Read content from file
	fd = open(file_name, O_RDONLY);
	char buffer[1000];
	count = read(fd, buffer, sizeof buffer);
	printf("%d bytes read\n", (int) count);
	buffer[count] = 0;
	printf("%s", buffer);

	// Truncate content
	fd = open(file_name, O_TRUNC | O_WRONLY, 0660);
	text = "Rewriting content of file.\n";
	count = write(fd, text, strlen(text));
	printf("%d bytes written\n", count);
	close(fd);

	// Read truncated content
	fd = open(file_name, O_RDONLY);
	buffer[1000];
	count = read(fd, buffer, sizeof buffer);
	printf("%d bytes read\n", (int) count);
	buffer[count] = 0;
	printf("%s", buffer);

	// Close and delete 'open.txt'
	close(fd);
	unlink("open.txt");
}

