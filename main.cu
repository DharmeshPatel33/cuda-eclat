/*****************************************************
Frequent itemset mining with CUDA

Yi-Fang Chen (d05921016@ntu.edu.tw)
  Date: Dec 29, 2017

How to Build:
  nvcc main.cu -o fim.out --std=c++11

How to run: 
  executable_name data_file min_sup out_file
  Example:
  ./fim.out retail.txt  0.1 output.txt

  <TEST version>
  
   ./fim.out retail.txt  0.1 output.txt  num_block num_thread

********************************************************/

#include"cuda_runtime.h"
#include"cuda.h"
#include"cuda_runtime_api.h"
#include<iostream>
#include<fstream>
#include<cstdio>
#include<vector>
#include<set>
#include<map>
#include<bitset>
#include "error.h"
#include "time.h"
#include "ResizableArray.h"
#include "device_launch_parameters.h"
#include <stdio.h>

int THREADNUM = 1024;
int BLOCKNUM = 20;

struct ItemDetail{
	int id;
	int realId;
	vector<int> tid;
	ItemDetail(int i = -1, int r = -1){
		id = i;
		realId = r;
	}
};

struct Item{
	int id;
	int* db;
	int support;
	Item(int i, int*d, int s){
		id = i;
		db = d;
		support = s;
	}
};

struct EClass{
	vector<Item> items;
	vector<int> parents;
};

 
const unsigned int Bit32Table[32] =
{
	2147483648UL, 1073741824UL, 536870912UL, 268435456UL,
	134217728, 67108864, 33554432, 16777216,
	8388608, 4194304, 2097152, 1048576,
	524288, 262144, 131072, 65536,
	32768, 16384, 8192, 4096,
	2048, 1024, 512, 256,
	128, 64, 32, 16,
	8, 4, 2, 1
};

const int SIZE_OF_INT = sizeof(int)* 8;
using namespace std;
void ReadInput(FILE *inputFile, int *tNum, int *iNum, int *&index, float supPer, EClass* &root);
void mineGPU(EClass* eClass, int minSup, int* index, int length);
void mineCPU(EClass* eClass, int minSup, int* index, int length);
int NumberOfSetBits(int i);

//----------------
// joseph add, Dec 29,2017
__global__ void intersect(int *a,int *b,int *c,int size,int *support);
__device__  int NumberOfSetBits_k(int i);


#define DEBUG 0
#define DYNAMIC 0



#if DYNAMIC

int grid_dim=16;
int block_dim=16;
#else
 #define grid_dim 16
 #define num_thread 16
 #define block_dim ((((num_thread)+(grid_dim)-1))/(grid_dim))
#endif
auto out = &cout;

int main(int argc, char** argv){

 
	
	clock_t tProgramStart = clock();
	bool cpu = true;
	bool gpu = true;
	char* inFileName = NULL; // the input file name
	float supPer = 0;// user specified minimun support percentage
	double time_gpu;
	double time_cpu;
	
	#if DYNAMIC
	   if ( argc != 6){
		   
		   printf("input argument wrong, return error;\n");
		   return 0;
	
	   }
      // argv4: number of block
	  grid_dim=atoi(argv[4]);
	  //argv5: number of thread
	  int num_thread=atoi(argv[5]);
	  block_dim=(num_thread+grid_dim-1)/grid_dim;

	 
	
	#else
	
	if ( argc != 4){//input argument wrong, print usage, return error;
		ErrorHandler(ERROR_INPUT);
	}
	
	#endif

	//set arguments
	inFileName = argv[1];
	if ((supPer = atof(argv[2])) == 0 || supPer > 100 || supPer < 0)
		ErrorHandler(ERROR_MINSUP);
    ofstream ofs;
	ofs.open(argv[3], ofstream::out | ofstream::trunc);
	out = &ofs;
	
	ofstream ofs1;
	ofs1.open("log.txt", ofstream::out | ofstream::app);
	auto fout = &ofs1;
	

	
	
	cout << "inFileName = " << inFileName << endl;
	cout << "minSup = " << supPer << endl;
	cout << "grid_dim = " << grid_dim << endl;
	cout << "block_dim = " << block_dim << endl;


	FILE *inputFile; // input file pointer
	int tNumbers = 0; // Transaction numbers
	int iNumbers = 0; // Item numbers
	int *index = NULL; // the index of item in the database, cause we only want to leave the items that are frequent
	EClass *root = new EClass();
	if ((inputFile = fopen(inFileName, "r")) == 0)
		ErrorHandler(ERROR_INFILE);
	ReadInput(inputFile, &tNumbers, &iNumbers, index, supPer, root);
	int length = tNumbers + SIZE_OF_INT - (tNumbers%SIZE_OF_INT);
	length /= SIZE_OF_INT;
	int minSup = tNumbers * supPer + 1;
	if (cpu){
		clock_t tCPUMiningStart = clock();		
		mineCPU(root, minSup, index, length);
		time_cpu=(double)(clock() - tCPUMiningStart) / CLOCKS_PER_SEC ;
		cout << "Time on CPU Mining: " << time_cpu << endl;
	}
	
	
	if (gpu){
		clock_t tGPUMiningStart = clock();
		mineGPU(root, minSup, index, length);
		time_gpu=(double)(clock() - tGPUMiningStart) / CLOCKS_PER_SEC ;
		cout << "Time on GPU Mining: " << time_gpu << endl;
	}
	



	
	for (auto item : root->items){
		delete[] item.db;
	}
	delete root;
	delete index;

	
	// --write to log for plotting------

	*fout << supPer << " " << grid_dim<< " " << num_thread << " " << time_gpu << " " << time_cpu << endl;
	
	
	//-------------------------------------
	
	
	
	ofs.close();
	ofs1.close();
  
  

	cudaDeviceSynchronize();
	return 0;
}

/**
* Read the input from database and store it in memory
* Would filter the items without minimun support
*
* @params
* inputFile: input file pointer
* tNum: record the transaction numbers
* iNum: record the item numbers
* index: conversion from id to real id, used for result output
* supPer: minimun support percentage
* eNum: record the effective item numbers (item with support > minimun support)
*/
void ReadInput(FILE *inputFile, int *tNum, int *iNum, int *&index, float supPer, EClass*&root){
	*tNum = 0;

	map<int, ItemDetail> mapIndex; // store the real id of items and the corresponding ItemDetail.
	char c = 0;
	int temp = 0;
	// read db and convert horizontal database to vertical database and store in the vector of the item in the map
	while ((c = getc(inputFile)) != EOF){
		if (c == ' ' || c == ',' || c == '\n'){
			if (mapIndex.find(temp) == mapIndex.end()){
				mapIndex[temp] = ItemDetail(0, temp);
				mapIndex[temp].tid.push_back(*tNum);
			}
			else mapIndex.find(temp)->second.tid.push_back(*tNum);
			temp = 0;
			if (c == '\n') (*tNum)++;
		}
		else if (47 < c <58){
			temp *= 10;
			temp += c - 48;
		}
	}

	//remove the item without minimun support
	int minSup = (*tNum)*supPer + 1;
	for (map<int, ItemDetail>::iterator it = mapIndex.begin(); it != mapIndex.end();){
		if (it->second.tid.size() < minSup) {
			map<int, ItemDetail>::iterator toErase = it;
			++it;
			mapIndex.erase(toErase);
		}
		else ++it;
	}

	// convert the tidset into bit vector and store in db, build index
	int bitLength = (*tNum) + SIZE_OF_INT - (*tNum) % SIZE_OF_INT;
	temp = 0;
	index = new int[mapIndex.size()];
	for (map<int, ItemDetail>::iterator it = mapIndex.begin(); it != mapIndex.end(); ++it){
		it->second.id = temp;
		index[temp] = it->second.realId;
		//int * bitVector = (db + temp * bitLength / SIZE_OF_INT);
		int* bitVector = new int[bitLength / SIZE_OF_INT];
		memset(bitVector, 0, sizeof(int)* bitLength / SIZE_OF_INT);
		for (int i = it->second.tid.size() - 1; i >= 0; i--){
			bitVector[it->second.tid[i] / SIZE_OF_INT] |= Bit32Table[it->second.tid[i] % SIZE_OF_INT];
		}
		(*root).items.push_back(Item(temp, bitVector, it->second.tid.size()));
		temp++;
	}
	*iNum = mapIndex.size();
}


/////////////////////////////////////////////////////////////////////

__global__ void intersect(int *a,int *b,int *c,int size,int *support)
{
	// TODO: fill this function to use gpu to accelerate the process of eclat
    #if DYNAMIC
	  	extern __shared__ int s[];
        int *cache_result=s;
	#else 
    __shared__ int cache_result[block_dim];
    #endif
	
	int temp = 0;

	int tid = threadIdx.x + blockDim.x * blockIdx.x;
	
	while (tid < size) {
	     c[tid]=a[tid] & b[tid];
		 temp += NumberOfSetBits_k(c[tid]);
		 tid += blockDim.x * gridDim.x;  
     }

	cache_result[threadIdx.x] = temp;
	
	__syncthreads();


	int i = blockDim.x / 2;
	while (i != 0)
	{
		if (threadIdx.x < i)
		{
			cache_result[threadIdx.x] += cache_result[i + threadIdx.x];
			
		}
		__syncthreads();
		i /= 2;
	}
	

	if (threadIdx.x == 0)
	{
		support[blockIdx.x] = cache_result[0];
		

	}
	
	
}

__device__  int NumberOfSetBits_k(int i)
{
        i = i - ((i >> 1) & 0x55555555);
        i = (i & 0x33333333) + ((i >> 2) & 0x33333333);
        return (((i + (i >> 4)) & 0x0F0F0F0F) * 0x01010101) >> 24;
}


///////////////////////////////////////////////////////////

/**
*	Mining Frequent itemset on GPU
* 
*	@Params
*	eClass: pointer to the equivalent class to explore
*	minSup: minimun support
*	index: array that map item id to real id, used for result output
*	length: the length of tidset in integer	
*
*/

//////////////////////////////////////////////////////////////////////////
unsigned long len=0;

void mineGPU(EClass *eClass, int minSup, int* index, int length){
	int size = eClass->items.size();
    //cout << size << endl;
	
	for (int i = 0; i < size; i++){
		EClass* children = new EClass();
		children->parents = eClass->parents;
		children->parents.push_back(eClass->items[i].id);
		int *a = eClass->items[i].db;
		for (int j = i + 1; j < size; j++){
			int * temp = new int[length];
			int *b = eClass->items[j].db;
			int support = 0;
			
			#if 1
			{ 	 // intersect in GPU
				   
	              int *dev_a,*dev_b,*dev_temp,*dev_support;
				  int size=length * sizeof(int); //length: # of int-size
				  int *support_a = (int *)malloc(grid_dim * sizeof(int));

				  cudaMalloc(&dev_a, size);
				  cudaMalloc(&dev_b, size);
				  cudaMalloc(&dev_temp, size);
				  cudaMalloc(&dev_support, grid_dim*sizeof(int));
				  cudaMemcpy(dev_a, a, size, cudaMemcpyHostToDevice);
				  cudaMemcpy(dev_b, b, size, cudaMemcpyHostToDevice);
				  #if DYNAMIC
				   intersect<<<grid_dim, block_dim,block_dim*sizeof(int)>>>(dev_a, dev_b,dev_temp,length,dev_support);
				  #else 
				  intersect<<<grid_dim, block_dim>>>(dev_a, dev_b,dev_temp,length,dev_support);
				  #endif
				  cudaMemcpy(temp, dev_temp, size, cudaMemcpyDeviceToHost);
				  cudaMemcpy(support_a, dev_support, grid_dim * sizeof(int), cudaMemcpyDeviceToHost);
				  
				
					for (int i = 0; i < grid_dim; i++)
					{	
						support += support_a[i];
							
	
					}
				  free(support_a);
				  cudaFree(dev_a);
	              cudaFree(dev_b);
				  cudaFree(dev_temp);
	              cudaFree(dev_support);
				  
				 
			}
		
			#else 
				 //intersect in CPU
			 for (int k = 0; k < length; k++){
				temp[k] = a[k] & b[k];
				support += NumberOfSetBits(temp[k]);
			 }
										
			#endif
			if (support >= minSup){
				children->items.push_back(Item(eClass->items[j].id, temp, support));
			}
			else delete[] temp;
		}
		if (children->items.size() != 0)
			mineGPU(children, minSup, index, length);
		for (auto item : children->items){
			delete[] item.db;
		}
		delete children;
	}
	

	#if 1
	
	for (auto item : eClass->items){ 
		
		for (auto i : eClass->parents) {
			*out << index[i] << " ";
			//cout << index[i] << " ";
		}

		 *out << index[item.id] << "(" << item.support << ")" << endl;
		 //cout << index[item.id] << "(" << item.support << ")" << endl;

		 
	
	}
	#endif
}



//////////////////////////////////////////////////////////////////
void mineCPU(EClass *eClass, int minSup, int* index, int length){
	
	
	int size = eClass->items.size();
	// cout <<"mineCPU" << size << endl;
	for (int i = 0; i < size; i++){
		EClass* children = new EClass();
		children->parents = eClass->parents;
		children->parents.push_back(eClass->items[i].id);
		int *a = eClass->items[i].db;
		for (int j = i + 1; j < size; j++){
			int * temp = new int[length];
			int *b = eClass->items[j].db;
			int support = 0;
			for (int k = 0; k < length; k++){
				temp[k] = a[k] & b[k];
				support += NumberOfSetBits(temp[k]);
			}
			if (support >= minSup){
				children->items.push_back(Item(eClass->items[j].id, temp, support));
			}
			else delete[] temp;
		}
		if (children->items.size() != 0)
			mineCPU(children, minSup, index, length);
		for (auto item : children->items){
			delete[] item.db;
		}
		delete children;
	}
	#if DEBUG

	for (auto item : eClass->items){ 
		
		for (auto i : eClass->parents) {
			cout << index[i] << " ";

		}
		cout << index[item.id] << "(" << item.support << ")" << endl;
	
	}
	#endif
}
int NumberOfSetBits(int i)
{
        i = i - ((i >> 1) & 0x55555555);
        i = (i & 0x33333333) + ((i >> 2) & 0x33333333);
        return (((i + (i >> 4)) & 0x0F0F0F0F) * 0x01010101) >> 24;
}

