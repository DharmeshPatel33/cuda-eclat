#######################################
#Frequent itemset mining with CUDA    #
#                                     #
# Yi-Fang Chen (d05921016@ntu.edu.tw) #
#  Date: Dec 29, 2017                 #
#######################################

echo "CUDA performance testing ...";
rm -rf log.txt
file='retail.txt'

#./fim.out retail.txt 0.01 output.txt $grid_dim $block_dim

for support in 0.0006 0.0007 0.0008 0.0009 0.001 ; do    #support 
	for grid_dim in 16 32 64 128 ; do    #grid_dim
		for thread_num in 16 32 64 128 ; do   #block_dim
			echo "support:$support,grid_dim:$grid_dim,block_dim:$block_dim"
			./fim.out $file $support output.txt $grid_dim $thread_num
			
		done
	done
done
