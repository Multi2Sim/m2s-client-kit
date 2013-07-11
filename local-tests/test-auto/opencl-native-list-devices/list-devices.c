#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <CL/cl.h>

void error(char *msg)
{
	fprintf(stderr, "error: %s\n", msg);
	exit(1);
}


void print_devices(cl_device_id *devices, cl_uint num_devices)
{
	cl_int ret;
	char device_name[300];
	int i;

	for (i = 0; i < num_devices; i++)
	{
		ret = clGetDeviceInfo(devices[i], CL_DEVICE_NAME, sizeof device_name, device_name, NULL);
		if (ret != CL_SUCCESS)
			error("call to 'clGetDeviceInfo' failed");
		printf("%d. %s\n", i + 1, device_name);
	}
	printf("\n");
}


int main(int argc, char **argv)
{

	cl_int ret;


	/*
	 * Platform
	 */

	/* Get platform */
	cl_platform_id platform;
	cl_uint num_platforms;
	ret = clGetPlatformIDs(1, &platform, &num_platforms);
	if (ret != CL_SUCCESS)
		error("second call to 'clGetPlatformIDs' failed");
	printf("Number of platforms: %d\n", num_platforms);

	/* Get platform name */
	char platform_name[100];
	ret = clGetPlatformInfo(platform, CL_PLATFORM_NAME, sizeof(platform_name), platform_name, NULL);
	if (ret != CL_SUCCESS)
		error("call to 'clGetPlatformInfo' failed");
	printf("platform.name='%s'\n", platform_name);
	printf("\n");



	/*
	 * Device
	 */

#define MAX_DEVICES 20
	cl_device_id devices[MAX_DEVICES];
	cl_uint num_devices;

	/* Get CPU devices */
	ret = clGetDeviceIDs(platform, CL_DEVICE_TYPE_CPU, MAX_DEVICES,
		devices, &num_devices);
	if (ret != CL_SUCCESS)
		error("call to 'clGetDeviceIDs' failed");
	printf("List of CPU devices:\n");
	print_devices(devices, num_devices);

	/* Get GPU devices */
	ret = clGetDeviceIDs(platform, CL_DEVICE_TYPE_GPU, MAX_DEVICES,
		devices, &num_devices);
	if (ret != CL_SUCCESS)
		error("call to 'clGetDeviceIDs' failed");
	printf("List of GPU devices:\n");
	print_devices(devices, num_devices);

	/* Get accelerator devices */
	ret = clGetDeviceIDs(platform, CL_DEVICE_TYPE_ACCELERATOR, MAX_DEVICES,
		devices, &num_devices);
	if (ret != CL_SUCCESS)
		error("call to 'clGetDeviceIDs' failed");
	printf("List of accelerator devices:\n");
	print_devices(devices, num_devices);

	/* Get all devices */
	ret = clGetDeviceIDs(platform, CL_DEVICE_TYPE_ALL, MAX_DEVICES,
		devices, &num_devices);
	if (ret != CL_SUCCESS)
		error("call to 'clGetDeviceIDs' failed");
	printf("List of all devices:\n");
	print_devices(devices, num_devices);

	return 0;
}

