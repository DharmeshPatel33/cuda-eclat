set autoscale 
set title 'Total thread=256, Support=1%'  font ",16"       # plot title
set xlabel 'The number of blocks' font ",12"     
set ylabel 'Time (second)' font ",12"                                  # x-axis label
                    # y-axis label
set yrange [1.9:2]
#set xrange [1:8]

#set label 'Yi-Fang Chen' at 12,8

plot 'fig1.txt' index 0 with linespoints ls 1