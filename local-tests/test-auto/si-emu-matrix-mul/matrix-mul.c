#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <CL/cl.h>
	
void error(char *msg)
{
	fprintf(stderr, "error: %s\n", msg);
	exit(1);
}

void print_matrix(cl_int *matrix, int dim)
{
	int i, j;

	for (i = 0; i < dim; i++)
	{
		for (j = 0; j < dim; j++)
			printf("%3d ", matrix[i * dim + j]);
		printf("\n");
	}
	printf("\n");
}

int main(int argc, char **argv)
{
	/* Arguments */
	size_t dim;
	size_t ldim;
	if (argc != 3)
		error("syntax: ./matrix-mul <dim> <ldim>");
	dim = atoi(argv[1]);
	ldim = atoi(argv[2]);

	/* Get platform */
	cl_int ret;
	cl_platform_id platform;
	cl_uint num_platforms;
	ret = clGetPlatformIDs(1, &platform, &num_platforms);
	if (ret != CL_SUCCESS)
		error("call to 'clGetPlatformIDs' failed\n");

	/* Get device */
	cl_device_id device;
	cl_uint num_devices;
	ret = clGetDeviceIDs(platform, CL_DEVICE_TYPE_GPU, 1, &device, &num_devices);
	if (ret != CL_SUCCESS)
		error("call to 'clGetDeviceIDs' failed\n");
	
	/* Create context */
	cl_context context;
	context = clCreateContext(NULL, 1, &device, NULL, NULL, &ret);
	if (ret != CL_SUCCESS)
		error("call to 'clCreateContext' failed\n");
	
	/* Create command queue */
	cl_command_queue command_queue;
	command_queue = clCreateCommandQueue(context, device, 0, &ret);
	if (ret != CL_SUCCESS)
		error("call to 'clCreateCommandQueue' failed\n");
	
	/* Program source */
	const char *source_code =
		"__kernel void matrix_mul(\n"
		"	__read_only __global int *A,\n"
		"	__read_only __global int *B,\n"
		"	__write_only __global int *C,\n"
		"	__local int *BlockA,\n"
		"	__local int *BlockB)\n"
		"{\n"
		"	int dim = get_global_size(0);\n"
		"	int col = get_global_id(0);\n"
		"	int row = get_global_id(1);\n"
		"\n"
		"	int ldim = get_local_size(0);\n"
		"	int lcol = get_local_id(0);\n"
		"	int lrow = get_local_id(1);\n"
		"\n"
		"	int sum = 0;\n"
		"	int i, j;\n"
		"\n"
		"	for (i = 0; i < dim / ldim; i++)\n"
		"	{\n"
		"		BlockA[lrow * ldim + lcol] = A[row * dim + (i * ldim + lcol)];\n"
		"		BlockB[lrow * ldim + lcol] = A[(i * ldim + lrow) * dim + col];\n"
		"		barrier(CLK_LOCAL_MEM_FENCE);\n"
		"\n"
		"		for (j = 0; j < ldim; j++)\n"
		"			sum += BlockA[lrow * ldim + j] * BlockB[j * ldim + lcol];\n"
		"		barrier(CLK_LOCAL_MEM_FENCE);\n"
		"	}\n"
		"	C[row * dim + col] = sum;\n"
		"}\n";
	const size_t source_length = strlen(source_code);
	
	/* Create a program */
	cl_program program;
	program = clCreateProgramWithSource(context, 1, &source_code, &source_length, &ret);
	if (ret != CL_SUCCESS)
		error("call to 'clCreateProgramWithSource' failed\n");

	/* Build program */
	ret = clBuildProgram(program, 1, &device, NULL, NULL, NULL);
	if (ret != CL_SUCCESS)
		error("call to 'clBuildProgram' failed\n");

	/* Create kernel */
	cl_kernel kernel;
	kernel = clCreateKernel(program, "matrix_mul", &ret);
	if (ret != CL_SUCCESS)
		error("call to 'clCreateKernel' failed\n");
	
	/* Create and allocate host buffers */
	cl_int *host_matrix_a;
	cl_int *host_matrix_b;
	cl_int *host_matrix_c;
	host_matrix_a = malloc(dim * dim * sizeof(cl_int));
	host_matrix_b = malloc(dim * dim * sizeof(cl_int));
	host_matrix_c = malloc(dim * dim * sizeof(cl_int));

	/* Initialize host matrices A and B */
	int i;
	for (i = 0; i < dim * dim; i++)
	{
		host_matrix_a[i] = i;
		host_matrix_b[i] = i;
	}
	
	/* Create device buffers */
	cl_mem device_matrix_a;
	cl_mem device_matrix_b;
	cl_mem device_matrix_c;
	device_matrix_a = clCreateBuffer(context, CL_MEM_READ_ONLY,
		dim * dim * sizeof(cl_int), NULL, NULL);
	device_matrix_b = clCreateBuffer(context, CL_MEM_READ_ONLY,
		dim * dim * sizeof(cl_int), NULL, NULL);
	device_matrix_c = clCreateBuffer(context, CL_MEM_WRITE_ONLY,
		dim * dim * sizeof(cl_int), NULL, NULL);

	/* Copy source matrices */
	ret = clEnqueueWriteBuffer(command_queue, device_matrix_a, CL_TRUE,
		0, dim * dim * sizeof(cl_int), host_matrix_a, 0, NULL, NULL);
	ret |= clEnqueueWriteBuffer(command_queue, device_matrix_b, CL_TRUE,
		0, dim * dim * sizeof(cl_int), host_matrix_b, 0, NULL, NULL);
	if (ret != CL_SUCCESS)
		error("call to 'clEnqueueWriteBuffer' failed");
	
	/* Kernel arguments */
	ret = clSetKernelArg(kernel, 0, sizeof(cl_mem), &device_matrix_a);
	ret |= clSetKernelArg(kernel, 1, sizeof(cl_mem), &device_matrix_b);
	ret |= clSetKernelArg(kernel, 2, sizeof(cl_mem), &device_matrix_c);
	ret |= clSetKernelArg(kernel, 3, sizeof(cl_int) * ldim * ldim, NULL);
	ret |= clSetKernelArg(kernel, 4, sizeof(cl_int) * ldim * ldim, NULL);
	if (ret != CL_SUCCESS)
		error("call to 'clSetKernelArg' failed\n");
	
	/* Launch the kernel */
	size_t global_work_size[2] = { dim, dim };
	size_t local_work_size[2] = { ldim, ldim };
	ret = clEnqueueNDRangeKernel(command_queue, kernel, 2, NULL,
		global_work_size, local_work_size, 0, NULL, NULL);
	if (ret != CL_SUCCESS)
		error("call to 'clEnqueueNDRangeKernel' failed\n");

	/* Wait for it to finish */
	clFinish(command_queue);

	/* Receive buffer */
	ret = clEnqueueReadBuffer(command_queue, device_matrix_c, CL_TRUE,
		0, dim * dim * sizeof(cl_int), host_matrix_c, 0, NULL, NULL);
	if (ret != CL_SUCCESS)
		error("call to 'clEnqueueReadBuffer' failed\n");
	
	/* Self-check */
	cl_int *host_matrix_d;
	host_matrix_d = calloc(dim * dim, sizeof(cl_int));
	int j, k;
	for (i = 0; i < dim; i++)
		for (j = 0; j < dim; j++)
			for (k = 0; k < dim; k++)
				host_matrix_d[i * dim + j] +=
					host_matrix_a[i * dim + k] *
					host_matrix_b[k * dim + j];

	/* Compare */
	int failed = 0;
	for (i = 0; i < dim; i++)
		for (j = 0; j < dim; j++)
			if (host_matrix_c[i * dim + j] !=
					host_matrix_d[i * dim + j])
				failed++;
	if (failed)
		printf("Failed (%d positions differ)\n", failed);
	else
		printf("Passed!\n");
	return 0;
}

