#include <errno.h>
#include <pthread.h>
#include <signal.h>
#include <stdio.h>
#include <time.h>
#include <unistd.h>
#include <sys/time.h>

int pid;
pthread_t child_thread;

void *child_fn(void *arg)
{
	// Sleep 1 second
	sleep(1);

	// Send signal to parent
	kill(pid, SIGALRM);
}

void alarm_handler()
{
}

long long get_time()
{
	struct timeval tv;
	long long value;

	gettimeofday(&tv, NULL);
	value = (long long) tv.tv_sec * 1000000 + tv.tv_usec;
	return value;
}

int main()
{
	// Spawn child thread
	pid = getpid();
	signal(SIGALRM, alarm_handler);

	// Sleep for 2 seconds without any interruption
	struct timespec req;
	struct timespec rem;
	req.tv_sec = 2;
	req.tv_nsec = 0;
	rem.tv_sec = 0;
	rem.tv_nsec = 0;
	int ret = nanosleep(&req, &rem);
	printf("Return value = %d, errno = %d\n", ret, errno);
	printf("Checking interruption while 0 seconds left ... ");
	if (!rem.tv_sec && !rem.tv_nsec)
		printf("OK\n");
	else
		printf("Failed\n");

	// Sleep for 2 seconds, will be interrupted by child thread after 1
	// second with a SIGALRM signal
	pthread_create(&child_thread, NULL, child_fn, NULL);
	req.tv_sec = 2;
	req.tv_nsec = 0;
	rem.tv_sec = 0;
	rem.tv_nsec = 0;
	ret = nanosleep(&req, &rem);
	printf("Return value = %d, errno = %d\n", ret, errno);
	printf("Checking interruption while ~1s left ... ");
	double left = (double) rem.tv_sec + (double) rem.tv_nsec / 1e9;
	if (left <= 1.0 && left >= 0.7)
		printf("OK\n");
	else
		printf("Failed (time left = %gs)\n", left);

	// Block SIGALRM
	sigset_t set;
	sigemptyset(&set);
	sigaddset(&set, SIGALRM);
	sigprocmask(SIG_BLOCK, &set, NULL);

	// Sleep for 2 seconds. Child thread will try to interrupt with SIGALRM
	// but the signal is masked.
	pthread_create(&child_thread, NULL, child_fn, NULL);
	req.tv_sec = 2;
	req.tv_nsec = 0;
	rem.tv_sec = 0;
	rem.tv_nsec = 0;
	ret = nanosleep(&req, &rem);
	printf("Return value = %d, errno = %d\n", ret, errno);
	printf("Checking interruption while 0 seconds left ... ");
	if (!rem.tv_sec && !rem.tv_nsec)
		printf("OK\n");
	else
		printf("Failed\n");
	
	
	return 0;
}

