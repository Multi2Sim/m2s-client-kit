#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <CL/cl.h>

unsigned char *read_buffer(char *file_name, size_t *size_ptr)
{
	FILE *f;
	unsigned char *buf;
	size_t size;

	/* Open file */
	f = fopen(file_name, "rb");
	if (!f)
		return NULL;
	
	/* Obtain file size */
	fseek(f, 0, SEEK_END);
	size = ftell(f);
	fseek(f, 0, SEEK_SET);

	/* Allocate and read buffer */
	buf = malloc(size + 1);
	fread(buf, 1, size, f);
	buf[size] = '\0';

	/* Return size of buffer */
	if (size_ptr)
		*size_ptr = size;

	/* Return buffer */
	return buf;
}


int main(int argc, char **argv)
{

	cl_int ret;


	/*
	 * Command line
	 */
	char *source_path;
	if (argc != 2)
	{
		printf("syntax: %s <kernel-source>\n", argv[0]);
		exit(1);
	}
	source_path = argv[1];


	/*
	 * Platform
	 */

	/* Get platform */
	cl_platform_id platform;
	cl_uint num_platforms;
	ret = clGetPlatformIDs(1, &platform, &num_platforms);
	if (ret != CL_SUCCESS)
	{
		printf("error: second call to 'clGetPlatformIDs' failed\n");
		exit(1);
	}
	printf("Number of platforms: %d\n", num_platforms);

	/* Get platform name */
	char platform_name[100];
	ret = clGetPlatformInfo(platform, CL_PLATFORM_NAME, sizeof(platform_name), platform_name, NULL);
	if (ret != CL_SUCCESS)
	{
		printf("error: call to 'clGetPlatformInfo' failed\n");
		exit(1);
	}
	printf("platform.name='%s'\n", platform_name);
	printf("\n");



	/*
	 * Device
	 */

	/* Get device */
	cl_device_id device;
	cl_uint num_devices;
	ret = clGetDeviceIDs(platform, CL_DEVICE_TYPE_GPU, 1, &device, &num_devices);
	if (ret != CL_SUCCESS)
	{
		printf("error: call to 'clGetDeviceIDs' failed\n");
		exit(1);
	}
	printf("Number of devices: %d\n", num_devices);

	/* Get device name */
	char device_name[100];
	ret = clGetDeviceInfo(device, CL_DEVICE_NAME, sizeof(device_name), device_name, NULL);
	if (ret != CL_SUCCESS)
	{
		printf("error: call to 'clGetDeviceInfo' failed\n");
		exit(1);
	}
	printf("device.name='%s'\n", device_name);
	printf("\n");



	/*
	 * Context
	 */
	
	/* Create context */
	cl_context context;
	context = clCreateContext(NULL, 1, &device, NULL, NULL, &ret);
	if (ret != CL_SUCCESS)
	{
		printf("error: call to 'clCreateContext' failed\n");
		exit(1);
	}

	

	/*
	 * Command Queue
	 */
	
	/* Create command queue */
	cl_command_queue command_queue;
	command_queue = clCreateCommandQueue(context, device, 0, &ret);
	if (ret != CL_SUCCESS)
	{
		printf("error: call to 'clCreateCommandQueue' failed\n");
		exit(1);
	}
	printf("\n");



	/*
	 * Program
	 */
	
	/* Program source */
	const char *source;
	size_t source_length;

	/* Read binary */
	source = read_buffer(source_path, &source_length);
	if (!source)
	{
		printf("error: %s: cannot open kernel source\n", source_path);
		exit(1);
	}
	
	/* Create a program */
	cl_program program;
	program = clCreateProgramWithSource(context, 1, &source,
			&source_length, &ret);
	if (ret != CL_SUCCESS)
	{
		printf("error: call to 'clCreateProgramWithSource' failed\n");
		exit(1);
	}

	/* Build program */
	ret = clBuildProgram(program, 1, &device, NULL, NULL, NULL);
	if (ret != CL_SUCCESS )
	{
		size_t size;
		char *log;

		/* Get log size */
		clGetProgramBuildInfo(program, device, CL_PROGRAM_BUILD_LOG, 0, NULL, &size);

		/* Allocate log and print */
		log = malloc(size);
		clGetProgramBuildInfo(program, device, CL_PROGRAM_BUILD_LOG, size, log, NULL);
		printf("error: call to 'clBuildProgram' failed:\n%s\n", log);

		/* Free log and exit */
		free(log);
		exit(1);
	}
	printf("program built\n");
	printf("\n");



	/*
	 * Kernel
	 */
	
	/* Create kernel */
	cl_kernel kernel;
	kernel = clCreateKernel(program, "vector_add", &ret);
	if (ret != CL_SUCCESS)
	{
		printf("error: call to 'clCreateKernel' failed\n");
		exit(1);
	}
	printf("\n");


	/*
	 * Buffers
	 */
	
	/* Create and allocate host buffers */
	size_t num_elem = 10;

	cl_int *src1_host_buffer;
	cl_int *src2_host_buffer;
	cl_int *dst_host_buffer;
	src1_host_buffer = malloc(num_elem * sizeof(cl_int));
	src2_host_buffer = malloc(num_elem * sizeof(cl_int));
	dst_host_buffer = malloc(num_elem * sizeof(cl_int));

	/* Initialize host source buffer */
	int i;
	for (i = 0; i < num_elem; i++)
	{
		src1_host_buffer[i] = i;
		src2_host_buffer[i] = 100;
	}
	
	/* Create device source buffers */
	cl_mem src1_device_buffer;
	cl_mem src2_device_buffer;
	src1_device_buffer = clCreateBuffer(context, CL_MEM_READ_ONLY, num_elem * sizeof(cl_int), NULL, NULL);
	src2_device_buffer = clCreateBuffer(context, CL_MEM_READ_ONLY, num_elem * sizeof(cl_int), NULL, NULL);
	if (!src1_device_buffer || !src2_device_buffer)
	{
		printf("error: could not create destination buffer\n");
		exit(1);
	}

	/* Create device destination buffer */
	cl_mem dst_device_buffer;
	dst_device_buffer = clCreateBuffer(context, CL_MEM_WRITE_ONLY, num_elem * sizeof(cl_int), NULL, &ret);
	if (ret != CL_SUCCESS)
	{
		printf("error: could not create destination buffer\n");
		exit(1);
	}

	/* Copy buffer */
	ret = clEnqueueWriteBuffer(command_queue, src1_device_buffer, CL_TRUE,
		0, num_elem * sizeof(cl_int), src1_host_buffer, 0, NULL, NULL);
	ret |= clEnqueueWriteBuffer(command_queue, src2_device_buffer, CL_TRUE,
		0, num_elem * sizeof(cl_int), src2_host_buffer, 0, NULL, NULL);
	if (ret != CL_SUCCESS)
	{
		printf("error: call to 'clEnqueueWriteBuffer' failed\n");
		exit(1);
	}


	/*
	 * Kernel arguments
	 */
	
	ret = clSetKernelArg(kernel, 0, sizeof(cl_mem), &src1_device_buffer);
	ret |= clSetKernelArg(kernel, 1, sizeof(cl_mem), &src2_device_buffer);
	ret |= clSetKernelArg(kernel, 2, sizeof(cl_mem), &dst_device_buffer);
	if (ret != CL_SUCCESS)
	{
		printf("error: call to 'clSetKernelArg' failed\n");
		exit(1);
	}
	
	
	/*
	 * Launch Kernel
	 */
	
	size_t global_work_size = num_elem;
	size_t local_work_size = num_elem;

	/* Launch the kernel */
	ret = clEnqueueNDRangeKernel(command_queue, kernel, 1, NULL,
		&global_work_size, &local_work_size, 0, NULL, NULL);
	if (ret != CL_SUCCESS)
	{
		printf("error: call to 'clEnqueueNDRangeKernel' failed\n");
		exit(1);
	}

	/* Wait for it to finish */
	clFinish(command_queue);


	/*
	 * Result
	 */
	
	/* Receive buffer */
	ret = clEnqueueReadBuffer(command_queue, dst_device_buffer, CL_TRUE,
		0, num_elem * sizeof(cl_int), dst_host_buffer, 0, NULL, NULL);
	if (ret != CL_SUCCESS)
	{
		printf("error: call to 'clEnqueueReadBuffer' failed\n");
		exit(1);
	}

	/* Print result */
	for (i = 0; i < num_elem; i++)
		printf("dst_host_buffer[%d] = %d\n", i, dst_host_buffer[i]);
	printf("\n");

	return 0;
}

