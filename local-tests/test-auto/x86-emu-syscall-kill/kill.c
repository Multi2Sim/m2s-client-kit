#include <signal.h>
#include <stdio.h>

void handler(int sig)
{
	printf("Signal %d received\n", sig);
}

int main()
{
	signal(SIGALRM, handler);
	kill(getpid(), SIGALRM);
	printf("Program finished\n");
	return 0;
}

