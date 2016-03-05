#define _GNU_SOURCE
#include <errno.h>
#include <stdio.h>
#include <sched.h>

int main()
{
	// Print original affinity
	cpu_set_t mask;
	sched_getaffinity(0, sizeof(cpu_set_t), &mask);
	printf("Initial affinity: %x\n", * (int *) &mask);

	// Set empty affinity - should cause an error
	CPU_ZERO(&mask);
	int err = sched_setaffinity(0, sizeof(cpu_set_t), &mask);
	printf("Setting affinity to %x - err=%d - errno=%d\n",
			* (int *) &mask, err, errno);

	// Set affinity to only use node 1
	CPU_SET(1, &mask);
	err = sched_setaffinity(0, sizeof(cpu_set_t), &mask);
	printf("Setting affinity to %x - err=%d\n",
			* (int *) &mask, err);
	
	// Read new affinity
	CPU_ZERO(&mask);
	sched_getaffinity(0, sizeof(cpu_set_t), &mask);
	printf("New affinity: %x\n", * (int *) &mask);

	// Done
	return 0;
}

