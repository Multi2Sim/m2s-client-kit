#include <iostream>
#include <cuda.h>
#define vect_len 120
using namespace std;

const int blocksize = 50;

// __global__ decorator signifies a kernel that can be called from the host
__global__ void vec_con_0(int *a, int *b, int n)
{
	int id = threadIdx.x + blockDim.x * blockIdx.x ;
	for (int i = 0; i < n; i++)
	{

		if (i < 5)
		{
			if (i > 2 )
				continue;
				//break;
			else
			{
				if (id < 16)
				{
					a[id] += 1;
				}
				else
					continue;
			}
		}
		else  
		{
			if (i < 8)
			{
				if (id >15)
				{
					a[id] += 2;
				}
				else
					break;
			}
			else
				break;
		}
		a[id] += 1;
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
	//vect_add<<<dimGrid, dimBlock>>>(ad, bd);
	vec_con_0<<<dimGrid, dimBlock>>>(ad, bd, 10);
	cudaMemcpy( result_v1, ad, vect_size, cudaMemcpyDeviceToHost );
	cudaMemcpy( result_v2, bd, vect_size, cudaMemcpyDeviceToHost );

	//Verify
	flag = true;

	for(int i = 0; i < vect_len; i++)
	{
		if (i < 16)
		{
			if (result_v1[i] != i + 6)
			{
				cout << " Test 0 Error at " << i << " expecting "
				<< i + 6 << " getting " << result_v1[i] <<endl;
				flag = false;
			}
			
		}
		else
		{
			if (result_v1[i] != i + 9)
			{
				cout << "Test 0 Error at " << i << " expecting "
				<< i + 9 << " getting " << result_v1[i] <<endl;
				flag = false;
			}
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



