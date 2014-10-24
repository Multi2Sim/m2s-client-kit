#include <iostream>
#include <cuda.h>
#define vect_len 120
using namespace std;

const int blocksize = 50;

// __global__ decorator signifies a kernel that can be called from the host
	
__global__ void vec_con_2(int *a, int *b, int n)
{
	int id = threadIdx.x + blockIdx.x * blockDim.x;

	if (id > 5)
	{	
		int i = 0;
		do
		{
			if (id > 10)
				a[id] += b[id];
			else
			{
				if (id < 7)
					break;
				else
				{
					a[id] += 1;
					continue;
				}
			}
		} while((id + i++) < 20);
	}
}


int main(){

	const int vect_size = vect_len*sizeof(int);
	int * vect1=(int*)malloc(vect_size);
	int * vect2=(int*)malloc(vect_size);
	int * result_v1=(int*)malloc(vect_size);
	int * result_v2=(int*)malloc(vect_size);
 	bool flag;

	for(int i = 0; i < vect_len; i++)
	{
		vect1[i] = i;
		vect2[i] = 2 * i;
	}
	int *ad, *bd;
	// initialize device memory
	cudaMalloc( (void**)&ad, vect_size );
	cudaMalloc( (void**)&bd, vect_size );
	// copy data to device
	cudaMemcpy( ad, vect1, vect_size, cudaMemcpyHostToDevice );
	cudaMemcpy( bd, vect2, vect_size, cudaMemcpyHostToDevice );
	// setup block and grid size	
	dim3 dimBlock( blocksize, 1, 1);
	dim3 dimGrid((vect_len + blocksize - 1)/blocksize, 1 , 1);

	// call device kernel
	vec_con_2<<<dimGrid, dimBlock>>>(ad, bd, 10);
	cudaMemcpy( result_v1, ad, vect_size, cudaMemcpyDeviceToHost );
	cudaMemcpy( result_v2, bd, vect_size, cudaMemcpyDeviceToHost );

	int* a = (int*)calloc(vect_len, sizeof(int));
	int* b = (int*)calloc(vect_len, sizeof(int));

	for (int i = 0; i < vect_len; i++)
	{
		a[i] = i;
		b[i] = 2 * i;
	}

	for (int id = 0; id < vect_len; id++)
	{
		if (id > 5)
		{	
			int i = 0;
			do
			{
				if (id > 10)
					a[id] += b[id];
				else
				{
					if (id < 7)
						break;
					else
					{
						a[id] += 1;
						continue;
					}
				}
			} while((id + i++) < 20);
		}
	}

	flag = true;

	for(int i = 0; i < vect_len; i++)
	{
		if (result_v1[i] != a[i])
		{
			cout << "Test2 failed at a " << i
				<< " expecting " << a[i] 
				<< " getting " << result_v1[i]<< endl;
			flag = false;
		}
		if (result_v2[i] != b[i])
		{
			cout << "Test2 failed at b " << i
				<< " expecting " << b[i]
				<< " getting " << result_v2[i]<< endl;
			flag = false;
		}
	}

	if(flag)
		cout << "Verification test passes." <<endl;

	// free device memory
	cudaFree( ad );
	cudaFree( bd );
	free(vect1);
	free(vect2);
	free(result_v1);
	free(result_v2);
	return EXIT_SUCCESS;
}



