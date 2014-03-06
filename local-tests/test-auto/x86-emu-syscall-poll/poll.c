#include <errno.h>
#include <poll.h>
#include <pthread.h>
#include <unistd.h>
#include <signal.h>
#include <stdio.h>
#include <string.h>

int pipefd[2];

void *child_fn(void *arg)
{
	// Delay
	sleep(2);

	// Write to pipe
	printf("Child writing to pipe\n");
	char *s = "hello";
	write(pipefd[1], s, strlen(s) + 1);
}

void handler(int sig)
{
	printf("Signal %d received\n", sig);
}

int main()
{
	// Create pipe
	printf("Creating pipe\n");
	int ret = pipe(pipefd);
	printf("ret = %d, errno = %d\n\n", ret, errno);

	// Spawn child thread
	pthread_t child_thread;
	pthread_create(&child_thread, NULL, child_fn, NULL);

	// Wait for event in pipe read descriptor, with a timeout of 1s
	printf("Running 'poll' on pipe read descriptor with a 1s timeout...\n");
	struct pollfd pollfd;
	pollfd.fd = pipefd[0];
	pollfd.events = POLLIN;
	ret = poll(&pollfd, 1, 1000);
	printf("ret = %d, errno = %d\n\n", ret, errno);
	
	// Wait for event in pipe read descriptor, without a timeout
	printf("Running 'poll' on pipe read descriptor without a timeout...\n");
	pollfd.fd = pipefd[0];
	pollfd.events = POLLIN;
	ret = poll(&pollfd, 1, -1);
	printf("ret = %d, errno = %d, pollfd.revents=0x%x\n\n",
			ret, errno, pollfd.revents);

	// Wait for event in pipe write descriptor, without a timeout
	printf("Running 'poll' on pipe write descriptor without a timeout...\n");
	pollfd.fd = pipefd[1];
	pollfd.events = POLLOUT;
	ret = poll(&pollfd, 1, -1);
	printf("ret = %d, errno = %d, pollfd.revents=0x%x\n\n",
			ret, errno, pollfd.revents);
}

