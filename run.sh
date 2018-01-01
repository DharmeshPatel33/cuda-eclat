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




#verify grid_dim

support=0.01
thread_num=256
for grid_dim in 16 32 64 128 256; do    
			./fim.out $file $support output.txt $grid_dim $thread_num
done



#verify thread_num 

support=0.01
grid_dim=8

for thread_num in  16 32 64 128 256; do    
			./fim.out $file $support output.txt $grid_dim $thread_num
done

#verify support 

grid_dim=8
thread_num=256

for support in 0.0006 0.0007 0.0008 0.0009 0.001 ; do    
			./fim.out $file $support output.txt $grid_dim $thread_num
done
