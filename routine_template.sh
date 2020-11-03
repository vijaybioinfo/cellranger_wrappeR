#!/bin/bash
  
  
#PBS -N {routine_pbs}_{sampleid}
#PBS -o {outpath}/../scripts/{routine_pbs}_{sampleid}.out.txt
#PBS -e {outpath}/../scripts/{routine_pbs}_{sampleid}.err.txt
#PBS -l walltime={walltime}
#PBS -q default
#PBS -l mem={mem}
#PBS -m abe
#PBS -M {username}@lji.org 
#PBS -l nodes={nodes}:ppn={ppn}
  
  
##########################################
#                                        #
#   Output some useful job information.  #
#                                        #
##########################################
  
echo ------------------------------------------------------
echo -n 'Job is running on node '; cat $PBS_NODEFILE
echo ------------------------------------------------------
echo PBS: qsub is running on $PBS_O_HOST
echo PBS: originating queue is $PBS_O_QUEUE
echo PBS: executing queue is $PBS_QUEUE
echo PBS: working directory is $PBS_O_WORKDIR
echo PBS: execution mode is $PBS_ENVIRONMENT
echo PBS: job identifier is $PBS_JOBID
echo PBS: job name is $PBS_JOBNAME
echo PBS: node file is $PBS_NODEFILE
echo PBS: current home directory is $PBS_O_HOME
echo PBS: PATH = $PBS_O_PATH
echo ------------------------------------------------------
  
# The working directory for the job is inside the scratch directory
WORKDIR=/mnt/beegfs/${USER}/cellranger/{sampleid}_PBS_$PBS_JOBID
  
# This is the directory on lysine where your project is stored
PROJDIR={outpath}
  
echo workdir is $WORKDIR
echo ------------------------------------------------------
echo -n 'Job is running on node '; cat $PBS_NODEFILE
echo ------------------------------------------------------
echo ' '
echo ' '
  
###############################################################
#                                                             #
#    Transfer files from server to local disk.                #
#                                                             #
###############################################################
  
stagein()
{
 echo ' '
 echo Transferring files from server to compute node
 echo Creating the working directory: $WORKDIR
 mkdir -p $WORKDIR
 echo Writing files in node directory  $WORKDIR
 cd $WORKDIR

 echo Files in node work directory are as follows:
 ls -l
}
  
############################################################
#                                                          #
#    Execute the run.  Do not run in the background.       #
#                                                          #
############################################################
  
runprogram()
{
 {cellranger} {routine} --id={sampleid} {routine_params}
}
  
###########################################################
#                                                         #
#   Copy necessary files back to permanent directory.     #
#                                                         #
###########################################################
  
stageout()
{
 echo ' '
 echo Transferring files from compute nodes to server
 echo Writing files in permanent directory  $PROJDIR
 cd $WORKDIR

 cp -R ./* $PROJDIR/
  
 echo Final files in permanent data directory:
 cd $PROJDIR
  
 #echo Removing the temporary directory from the compute node
 #rm -rf $WORKDIR
 }
   
##################################################
#                                                #
#   Staging in, running the job, and staging out #
#   were specified above as functions.  Now      #
#   call these functions to perform the actual   #
#   file transfers and program execution.        #
#                                                #
##################################################
  
stagein
runprogram
stageout
   
exit
