#include <stdio.h>
#include <sys/times.h>
#include <unistd.h>

int main()
{
	struct tms tms;
	int err = times(&tms);

	printf("Return value is %d\n", err);
	clock_t system_time = tms.tms_stime;

	printf("Sleep for 1 second...\n");
	sleep(1);

	printf("Run times() again\n");
	err = times(&tms);

	printf("Return value is %d\n", err);

	int ellapsed = tms.tms_stime - system_time;
	if (ellapsed < 0)
		printf("Error: Unexpected system time ellapsed\n");
	return 0;
}

