package MLocarna::threaded;

use strict;
use warnings;

use threads;
use threads::shared qw(share);
use Thread::Semaphore;

require Exporter;
our $VERISON = 1.00;
our @ISA = qw(Exporter);
our @EXPORT = qw(
    foreach_par
    threadsafe_name
    share);

## execute sub for all given argument lists in in parallel
##
# @param $sub_ref       --- reference to the sub-routine
# @param $argument_lists_ref --- reference to the list of argument-lists references
# @param $thread_num     --- number of parallel threads
#
# idea: use $thread_num worker threads. each thread gets a new job as
# long as there is one and processes the job. job reservation needs to
# be synchronized (by lock on shared var $job_count)
#
sub foreach_par {
    my ($sub_ref,$argument_lists_ref,$thread_num) = @_;

    my @argument_lists = @{ $argument_lists_ref };

    my $job_num=scalar(@argument_lists); ## total number of jobs

    my $job_count : shared = 0; ## count already started jobs

    my @workers;
    for (my $i=1; $i<=$thread_num; $i++) {
        $workers[$i]=
          threads->create(
              sub {
                  while(1) {
                      # get the job number
                      my $my_job;
                      {
                          lock($job_count);
                          $my_job=$job_count;
                          $job_count++;
                      }

                      ## if job number too large, then terminate thread
                      if ($my_job >= $job_num) {return;}

                      # run the job
                      $sub_ref->(@{ $argument_lists[$my_job] });
                  }
              }
         );
    }

    for (my $i=1; $i<=$thread_num; $i++) {
        $workers[$i]->join();
    }
}

## generate a thread-unique filename
sub threadsafe_name {
    my ($name) = @_;
    my $tid=threads->tid();
    if ($tid==0) { return $name; }
    else {return "$name$tid";}
}


return 1;
