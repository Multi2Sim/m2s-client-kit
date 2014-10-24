#include <iostream>
#include <cuda.h>
#define vect_len 33
using namespace std;

const int blocksize = 32;

// __global__ decorator signifies a kernel that can be called from the host
__global__ void vec_con_1(int *a, int *b, int n)
{
	int id = threadIdx.x + blockIdx.x * blockDim.x;
	if (id < vect_len)
		for (int j = 0; j < n; j++)
		{
			if (id < vect_len / 3)
				continue;
			else
			{
				if (id < vect_len / 3 * 2)
					a[id] +=10;
				else
				{
					b[id] += 4;
					if (b[id] == 200)
						break;
				}
				a[id] += 1;
			}
			b[id] += 1;
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
	vec_con_1<<<dimGrid, dimBlock>>>(ad, bd, 10);
	cudaMemcpy( result_v1, ad, vect_size, cudaMemcpyDeviceToHost );
	cudaMemcpy( result_v2, bd, vect_size, cudaMemcpyDeviceToHost );

	flag = true;

	for (int id = 0; id < vect_len; id++)
	{
		int a = id;
		int b = 2 * id;

		for (int j = 0; j < 10; j++)
		{
			if (id < vect_len / 3)
				continue;
			else
			{
				if (id < vect_len /3 * 2)
					a +=10;
				else
				{
					b += 4;
					if (b == 200)
						break;
				}
				a += 1;
			}
			b += 1;
		}

		if (a != result_v1[id])
		{
			cout << "Test 1 Error at a " << id << " expecting "
				<< a << " getting " << result_v1[id] <<endl;
			flag = false;
		}

		if (b != result_v2[id])
		{
			cout << "Test 1 Error at b " << id << " expecting "
				<< b << " getting " << result_v2[id] <<endl;
			flag = false;
		}
			
	}

	if(flag_1)
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



