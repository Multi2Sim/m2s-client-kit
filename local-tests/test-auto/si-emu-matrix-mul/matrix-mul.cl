__kernel void matrix_mul(
	__read_only __global int *A,
	__read_only __global int *B,
	__write_only __global int *C,
	__local int *BlockA,
	__local int *BlockB)
{
	int dim = get_global_size(0);
	int col = get_global_id(0);
	int row = get_global_id(1);

	int ldim = get_local_size(0);
	int lcol = get_local_id(0);
	int lrow = get_local_id(1);

	int sum = 0;
	int i, j;

	for (i = 0; i < dim / ldim; i++)
	{
		BlockA[lrow * ldim + lcol] = A[row * dim + (i * ldim + lcol)];
		BlockB[lrow * ldim + lcol] = A[(i * ldim + lrow) * dim + col];
		barrier(CLK_LOCAL_MEM_FENCE);

		for (j = 0; j < ldim; j++)
			sum += BlockA[lrow * ldim + j] * BlockB[j * ldim + lcol];
		barrier(CLK_LOCAL_MEM_FENCE);
	}
	C[row * dim + col] = sum;
}
