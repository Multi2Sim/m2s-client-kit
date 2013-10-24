__kernel void main()
{
	__local int* ptr;
	ptr[3] = 0;
	*ptr;
}
