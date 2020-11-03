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

# This job structure is based of:
# https://learn.lji.org/display/BIODOCS/Creating+a+Job
# https://learn.lji.org/display/BIODOCS/Job+Arrays

######################################################################
#                                                                    #
#   Preface of operations: introduce the code you need to prepare    #
#   your job's parameters; this is useful especially when            #
#   when you have an array                                           #
#                                                                    #
######################################################################

echo -----------------------------------------------------------------
echo -n 'Job is running on node '; cat ${PBS_NODEFILE}
echo -----------------------------------------------------------------
echo PBS: qsub is running on ${PBS_O_HOST}
echo PBS: originating queue is ${PBS_O_QUEUE}
echo PBS: executing queue is ${PBS_QUEUE}
echo PBS: working directory is ${PBS_O_WORKDIR}
echo PBS: execution mode is ${PBS_ENVIRONMENT}
echo PBS: job identifier is ${PBS_JOBID}
echo PBS: job name is ${PBS_JOBNAME}
echo PBS: node file is ${PBS_NODEFILE}
echo PBS: current home directory is ${PBS_O_HOME}
echo PBS: PATH = ${PBS_O_PATH}
echo -----------------------------------------------------------------

######################################################################
#                                                                    #
#   To minimize communications traffic, it is best for your job      #
#   to work with files on the local disk of the compute node.        #
#   Hence, one needs to transfer files from your permanent home      #
#   directory tree to the directory ${WORKDIR} automatically         #
#   created by PBS on the local disk before program execution,       #
#   and to transfer any important output files from the local        #
#   disk back to the permanent home directory tree after program     #
#   execution is completed.                                          #
#                                                                    #
######################################################################

# The working directory for the job is inside the scratch directory
WORKDIR=/mnt/beegfs/${USER}/cellranger/{sampleid}_PBS_${PBS_JOBID}

# This is the directory on lysine where your project is stored
PROJDIR={outpath}

######################################################################
#                                                                    #
#   Extra job monitoring code.                                       #
#                                                                    #
######################################################################

function logger(){
    echo "$(hostname) progress: $(date): $1"
}

######################################################################
#                                                                    #
#   Transfer files from server to local disk.                        #
#                                                                    #
######################################################################

stagein()
{
  echo ' '
  echo Transferring files from server to compute node
  echo Creating the working directory: ${WORKDIR}
  mkdir --parents ${WORKDIR}
  mkdir --parents ${PROJDIR}
  echo Writing files in node directory ${WORKDIR}
  cd ${WORKDIR}

  echo Files in node work directory are as follows:
  ls -loh
}

######################################################################
#                                                                    #
#   Execute the run.  Do not run in the background.                  #
#                                                                    #
######################################################################

runprogram()
{
  {routine_params}
}

######################################################################
#                                                                    #
#   Copy necessary files back to permanent directory.                #
#                                                                    #
######################################################################

stageout()
{
 echo ' '
 echo Transferring files from compute nodes to server
 echo Writing files in permanent directory  ${PROJDIR}
 cd ${WORKDIR}

 cp -R ./* ${PROJDIR}/

 echo Final files in permanent data directory:
 cd ${PROJDIR}
 ls -loh
}

######################################################################
#                                                                    #
#   The "qdel" command is used to kill a running job.  It first      #
#   sends a SIGTERM signal, then after a delay (specified by the     #
#   "kill_delay" queue attribute (set to 60 seconds), unless         #
#   overridden by the -W option of "qdel"), it sends a SIGKILL       #
#   signal which eradicates the job.  During the time between the    #
#   SIGTERM and SIGKILL signals, the "cleanup" function below is     #
#   run. You should include in this function commands to copy files  #
#   from the local disk back to your home directory.  Note: if you   #
#   need to transfer very large files which make take longer than    #
#   60 seconds, be sure to use the -W option of qdel.                #
#                                                                    #
######################################################################

early()
{
  echo ' '
  echo ' ############ WARNING:  EARLY TERMINATION #############'
  echo ' '
}
trap 'early; stageout' 2 9 15

######################################################################
#                                                                    #
#   The epilogue script automatically deletes the directory          #
#   created on the local disk (including all files contained         #
#   therein.                                                         #
#                                                                    #
######################################################################

statecopy()
{
  # Check if everything went well
  WCONTENT=(`ls ${WORKDIR}`)
  PCONTENT=(`ls ${PROJDIR}`)
  declare -p ALL_TRANSFERRED=()
  for i in "${WCONTENT[@]}"; do
      skip=
      for j in "${PCONTENT[@]}"; do
          [[ ${i} == ${j} ]] && { skip=1; break; }
      done
      [[ -n ${skip} ]] || ALL_TRANSFERRED+=("${i}")
  done
  if [[ ${#ALL_TRANSFERRED[@]} -eq 0 ]] && [[ -d ${WORKDIR}/outs ]]; then
   echo Removing the temporary directory from the compute node
   rm -rf ${WORKDIR}
  fi
}

######################################################################
#                                                                    #
#   Staging in, running the job, and staging out                     #
#   were specified above as functions.  Now                          #
#   call these functions to perform the actual                       #
#   file transfers and program execution.                            #
#                                                                    #
######################################################################

logger "Starting..."
stagein
logger "Main."
runprogram
logger "Wrapping up."
stageout
statecopy
logger "Finished."

exit
