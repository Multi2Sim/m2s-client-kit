#Simple Example File showing running a bunch of examples from APP SDK

clustername="opencl_suite"
sim-cluster.sh create $clustername

#DCT
multiple=128
for k in {1..5}
do
ipsize=$k
ipsize=$(( $k * $multiple ))
sim-cluster.sh add $clustername "dct$k" AMDAPP-2.5/DCT --sim-args "--gpu-sim detailed --gpu-config gpu-config --report-mem report_mem" --send ../testconfigs/gpu-config --bench-args "-q -x $ipsize --load DCT_Kernels.bin"
done

#URNG
for k in {1..5}
do
ipsize=$k
sim-cluster.sh add $clustername urng$k AMDAPP-2.5/URNG --sim-args "--gpu-sim detailed --gpu-config gpu-config --report-mem report_mem" --send ../testconfigs/gpu-config --bench-args "-q -x $ipsize --load URNG_Kernels.bin"
done

#DWT
multiple=512
for k in {1..5}
do
ipsize=$(( 2 ** k ))
ipsize=$(( $ipsize * $multiple ))
sim-cluster.sh add $clustername dwt$k AMDAPP-2.5/DwtHaar1D --sim-args "--gpu-sim detailed --gpu-config gpu-config --report-mem report_mem" --send ../testconfigs/gpu-config --bench-args "-q -x $ipsize --load DwtHaar1D_Kernels.bin"
done

#Sobel
for k in {1..5}
do
ipsize=$k
sim-cluster.sh add $clustername sobel$k AMDAPP-2.5/SobelFilter --sim-args "--gpu-sim detailed --gpu-config gpu-config --report-mem report_mem" --send ../testconfigs/gpu-config --bench-args "-q -x $ipsize --load SobelFilter_Kernels.bin"
done

sim-cluster.sh submit $clustername nyan.ece.neu.edu 
