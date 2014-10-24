#include <iostream>
#include <cuda.h>
#define vect_len 100
using namespace std;

const int blocksize = 50;

// __global__ decorator signifies a kernel that can be called from the host
__global__ void vec_con_0(int *a, int *b, int n)
{
	int id = threadIdx.x + blockDim.x * blockIdx.x ;

	if (id >vect_len / 2)
		a[id] += b[id];
	else
		a[id] += a[id];	
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

	for(int id = 0; id < vect_len; id++)
	{
		int a = id;
		int b = 2 * id;

		if (id > vect_len / 2)
			a += b;
		else
			a += a;	

		if (a != result_v1[id])
		{
			flag = false;
			cout<< "Failed at a " << id << " expecting " 
				<< a << " getting " << result_v1[id] << endl;
		}
		if (b != result_v2[id])
		{
			flag = false;
			cout<< "Failed at b " << id << " expecting " 
				<< a << " getting " << result_v2[id] << endl;
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



