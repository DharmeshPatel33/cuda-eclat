#include <iostream>

using namespace std;

const int ERROR_INPUT = -1;
const int ERROR_MINSUP = -2;
const int ERROR_INFILE = -3;



void ErrorHandler(const int error){
	switch (error){
		case ERROR_INPUT:{
							 cout << "invalid input argument" << endl;
							 cout << "usage: prog_name data_file min_support output_file" << endl;
							 exit(-1);
							 break;
		}
		case ERROR_MINSUP:{
							  cout << "invalid minimun support value" << endl;
							  exit(-1);
							  break;
		}
		case ERROR_INFILE:{
							  cout << "cannot open input file, does the file exist?" << endl;
							  exit(-1);
							  break;
		}
		default:{
					cout << "unknown error type" << endl;
		}
	}
}
