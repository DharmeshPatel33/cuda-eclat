all: fim.out 

fim.out: error.h ResizableArray.h main.cu
	nvcc main.cu -o fim.out --std=c++11

clean:
	rm -rf fim.out
