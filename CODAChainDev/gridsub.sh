#!/bin/bash

jobname=$1
do_sub=$2

run_list=$3
nevents=$4

if [ $do_sub == 1 ]; then
  echo "grid!"
else
  echo "local!"
fi

echo "run_list=$run_list"
echo "nevents=$nevents"

macros=$(dirname $(readlink -f $0))
echo "macros=$macros"

IFS=$'\n'       # make newlines the only separator
for run_num in $(cat $run_list) 
do
  coda_dir="/data3/data/mainDAQ/"
  coda_file="run_0${run_num}.dat"
  ls -lh $coda_dir/$coda_file

  # prepare $workdir
  if [ $do_sub == 1 ]; then
  local_work_dir=/pnfs/e906/persistent/users/$USER/CODAChainDev/$jobname/$run_num/
  else
  local_work_dir=$macros/scratch/$jobname/$run_num/
  fi
  mkdir -p $local_work_dir
  chmod -R 01755 $local_work_dir

  # prepare input for upload in the $local_work_dir
  cd $macros
  tar -zcvf $local_work_dir/input.tar.gz *.C *.opts
  if [ $do_sub == 1 ]; then
    rsync -av $coda_dir/$coda_file $local_work_dir/
  else
    ln -sf $coda_dir/$coda_file $local_work_dir/
  fi
  cd -

  mkdir -p $local_work_dir/log
  mkdir -p $local_work_dir/out
  chmod -R 01755 $local_work_dir

  rsync -a $macros/gridrun.sh $local_work_dir/gridrun.sh

  if [ $do_sub == 1 ]; then
    #cmd="--help"
    cmd="-g --OS=SL6 --use_gftp --resource-provides=usage_model=DEDICATED,OPPORTUNISTIC,OFFSITE -e IFDHC_VERSION --expected-lifetime='short'"
    cmd="$cmd --mail_never"
    cmd="$cmd -L $local_work_dir/log/log.txt"
    cmd="$cmd -f $local_work_dir/input.tar.gz"
    cmd="$cmd -f $local_work_dir/$coda_file"
    cmd="$cmd -d OUTPUT $local_work_dir/out"
    cmd="$cmd file://`which $local_work_dir/gridrun.sh` $nevents $run_num"
    echo "jobsub_submit $cmd"
    jobsub_submit $cmd
  else
    condor_work_dir=$local_work_dir/condor
    mkdir -p $condor_work_dir/input
    mkdir -p $condor_work_dir/out
    ln -sf $local_work_dir/gridrun.sh     $condor_work_dir/
    ln -sf $local_work_dir/input.tar.gz   $condor_work_dir/input
    ln -sf $local_work_dir/*.dat          $condor_work_dir/input
    cd $condor_work_dir
    ./gridrun.sh $nevents $run_num | tee $local_work_dir/log/log.txt
    cd -
  fi

done

