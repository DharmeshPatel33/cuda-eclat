set autoscale 
set title 'Total blocks=8, Support=1%'  font ",16"       # plot title
set xlabel 'The number of threads' font ",12"     
set ylabel 'Time (second)' font ",12"                                  # x-axis label
                    # y-axis label
set yrange [1.9:2.05]
#set xrange [1:8]

#set label 'Yi-Fang Chen' at 12,8

plot 'fig2.txt' index 0 with linespoints ls 1