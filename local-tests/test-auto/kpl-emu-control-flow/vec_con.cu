#include <iostream>
#include <cuda.h>
#define vect_len 33
using namespace std;

const int blocksize = 32;

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
 	bool flag, flag_1, flag_2;

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
		cout << "Verification test 0 passes." <<endl;

	// copy data to device
	cudaMemcpy( ad, vect1, vect_size, cudaMemcpyHostToDevice );
	cudaMemcpy( bd, vect2, vect_size, cudaMemcpyHostToDevice );

	vec_con_1<<<dimGrid, dimBlock>>>(ad, bd, 10);
	cudaMemcpy( result_v1, ad, vect_size, cudaMemcpyDeviceToHost );
	cudaMemcpy( result_v2, bd, vect_size, cudaMemcpyDeviceToHost );

	flag_1 = true;

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
			flag_1 = false;
		}

		if (b != result_v2[id])
		{
			cout << "Test 1 Error at b " << id << " expecting "
				<< b << " getting " << result_v2[id] <<endl;
			flag_1 = false;
		}
			
	}

	if(flag_1)
		cout << "Verification test 1 passes." <<endl;



	cudaMemcpy( ad, vect1, vect_size, cudaMemcpyHostToDevice );
	cudaMemcpy( bd, vect2, vect_size, cudaMemcpyHostToDevice );

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

	flag_2 = true;

	for(int i = 0; i < vect_len; i++)
	{
		if (result_v1[i] != a[i])
		{
			cout << "Test2 failed at a " << i
				<< " expecting " << a[i] 
				<< " getting " << result_v1[i]<< endl;
			flag_2 = false;
		}
		if (result_v2[i] != b[i])
		{
			cout << "Test2 failed at b " << i
				<< " expecting " << b[i]
				<< " getting " << result_v2[i]<< endl;
			flag_2 = false;
		}
	}

	if(flag_2)
		cout << "Verification test 2 passes." <<endl;

	// free device memory
	cudaFree( ad );
	cudaFree( bd );
	free(vect1);
	free(vect2);
	free(result_v1);
	free(result_v2);
	return EXIT_SUCCESS;
}



