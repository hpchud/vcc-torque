#!/bin/bash

echo "Waiting up to 60 seconds for the cluster to settle..."
sleep 60

NTOTAL="`cat /etc/hosts.vcc | wc -l`"
NWORKERS="`cat /var/spool/torque/server_priv/nodes | wc -l`"

echo "Total hosts: $NTOTAL"
echo "Worker nodes: $NWORKERS"

echo -n "TORQUE node check "

CHECK_NWORKERS="`pbsnodes -l free | wc -l`"

if [ "$CHECK_NWORKERS" == "$NWORKERS" ]; then
	echo "[OK]"
else
	echo "[FAILED]"
fi

echo "SSH test head->node"
PDSH_SSH_ARGS_APPEND="-oLogLevel=ERROR" pdsh -a "echo [OK]"

echo "SSH test head<-node"
PDSH_SSH_ARGS_APPEND="-oLogLevel=ERROR" pdsh -a "ssh -oLogLevel=ERROR headnode echo [OK]"

# example mpi code
cat <<EOF > /tmp/mpi-test.c
#include <mpi.h>
#include <stdio.h>
#include <unistd.h>

int main(int argc, char **argv)
{
  int rank;
  char hostname[256];

  MPI_Init(&argc,&argv);
  MPI_Comm_rank(MPI_COMM_WORLD, &rank);
  gethostname(hostname,255);

  printf("%s / %d [OK]\n", hostname, rank);

  MPI_Finalize();

  return 0;
}
EOF

cat /etc/hosts.vcc | awk '{print $1}' > /root/machines

module load mpi/mpich-x86_64
echo -n "MPICH compile "
mpicc -o /cluster/mpi-test.mpich /tmp/mpi-test.c
if [ $? -eq 0 ]; then
    echo "[OK]"
else
    echo "[FAILED]"
fi

echo "MPICH test (via mpirun)"
mpirun -machinefile /root/machines /cluster/mpi-test.mpich

module unload mpi/mpich-x86_64

#module load mpi/openmpi-x86_64
#echo -n "openMPI compile "
#mpicc -o /cluster/mpi-test.ompi /tmp/mpi-test.c
#if [ $? -eq 0 ]; then
#    echo "[OK]"
#else
#    echo "[FAILED]"
#fi

#echo "openMPI test (via mpirun)"
#mpirun --allow-run-as-root -machinefile /tmp/test.machinefile /cluster/mpi-test.ompi

echo ""
echo "Cluster test complete."
echo "If all tests passed with [OK] the cluster is ready."
