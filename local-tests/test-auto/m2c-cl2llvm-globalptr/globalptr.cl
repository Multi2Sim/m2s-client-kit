__kernel void main(__global int* x)
{
	x[2] = 0;
	*x;
}
