set autoscale 
set title 'Total blocks=8,Total threads=256'  font ",16"       # plot title
set xlabel 'Support percentage (%)' font ",12"     
set ylabel 'Time (second)' font ",12"                                  # x-axis label
                    # y-axis label
#set yrange [0:1]
#set xrange [1:8]

#set label 'Yi-Fang Chen' at 12,8

plot 'fig3.txt' index 0 with linespoints ls 1