__kernel void vector_add(
	__read_only __global int *src1,
	__read_only __global int *src2,
	__write_only __global int *dst)
{
	int i;
	int x;
	int id = get_global_id(0);

	x = 0;
	for (i = 0; i < id; i++)
	{
		x++;
	}
	dst[id] = x;
}

