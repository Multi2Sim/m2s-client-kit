#include <errno.h>
#include <pthread.h>
#include <unistd.h>
#include <signal.h>
#include <stdio.h>
#include <string.h>

int pipefd[2];
int parent_pid;

void *child_fn(void *arg)
{
	// Sleep for 1 second
	sleep(1);

	// Write into pipe
	printf("Child writing into pipe\n");
	char *s = "hello";
	write(pipefd[1], s, strlen(s) + 1);

	// Let parent perform a blocking read
	sleep(1);

	// Send signal to parent to interrupt blocking read, but the parent
	// will retry
	kill(parent_pid, SIGALRM);

	// Let parent execute its retry
	sleep(1);

	// And write a message for the parent
	s = "bye";
	write(pipefd[1], s, strlen(s) + 1);

	// Let parent execute another blocking read, this time it won't be
	// retried
	sleep(1);

	// Send signal to parent
	kill(parent_pid, SIGALRM);
}

void handler(int sig)
{
	printf("Signal %d received\n", sig);
}

int main()
{
	// Get pid
	parent_pid = getpid();

	// Create pipe
	printf("Creating pipe\n");
	int ret = pipe(pipefd);
	printf("ret = %d, errno = %d\n\n", ret, errno);

	// Spawn child thread
	pthread_t child_thread;
	pthread_create(&child_thread, NULL, child_fn, NULL);

	// Blocking read from the pipe
	char s[10];
	ret = read(pipefd[0], s, sizeof s);
	printf("Parent reads %d bytes from child: '%s' (errno = %d)\n\n",
			ret, s, errno);

	// Set signal handler of SIGALRM with flag SA_RESTART
	struct sigaction action;
	sigaction(SIGALRM, NULL, &action);
	action.sa_handler = &handler;
	action.sa_flags = SA_RESTART;
	sigaction(SIGALRM, &action, NULL);
	
	// Blocking read interrupted by signal, but restarted
	printf("Performing blocking read interrupted by signal and retried ...\n");
	ret = read(pipefd[0], s, sizeof s);
	printf("Parent reads %d bytes from child: '%s' (errno = %d)\n\n",
			ret, s, errno);

	// Set signal handler of SIGALRM without flag SA_RESTART
	action.sa_flags = 0;
	sigaction(SIGALRM, &action, NULL);

	// Blocking read interrupted by signal
	printf("Performing blocking read interrupted by signal and aborted ...\n");
	ret = read(pipefd[0], s, sizeof s);
	printf("ret = %d, errno = %d\n\n", ret, errno);

	// Wait for child
	pthread_join(child_thread, NULL);
}

