#!/usr/bin/env perl

=head1 NAME

locarnap-realign-all

=head1 SYNOPSIS

locarnap-realign-all [options] <annotation-file>

=head1 DESCRIPTION

Calls mlocarna on sequence sets in Realign-Sequences as generated by a
call to locarnap-revisit-RNAz-hits.pl. The script is usually used as
second step in a pipeline for refining RNAz hits with LocARNA-P.


=head1 OPTIONS

=over 4

=item  B<--help>

Brief help message

=item  B<--man>

Full documentation

=item  B<--test>

Test only. Jobs are not run or submitted to SGE!

=item  B<--revcompl>

Realign reverse complement

=item  B<--run-locally>

Run the realignment on the local machine (without the use of SGE).

=item  B<--threads=k>

Use <k> threads for multicore support.

=back


Writes result files to Alignment-Results, takes alignment jobs from
annotation file

Unless option --run-locally is given, distribute jobs to SGE-cluster,
where we assume that the script is run on a submission host!

=cut


use warnings;
use strict;


## ----------------------------------------
##
#constants

my $homedir = readpipe("pwd");
chomp $homedir;

my $source_dir=$homedir."/Realign-Sequences";
my $tgt_dir=$homedir."/Alignment-Results";
my $tmp_dir=$tgt_dir; # specify a directory with fast access from the
		      # compute server

my $locarna_bin = "";    ## specify full path to locarna binaries for
			 ## selecting a specific version as
			 ## "/home/will/Soft/locarna-1.4.8/bin/" or
			 ## when mlocarna is not in the search path
my $mlocarna=$locarna_bin."mlocarna"; 
my $mlocarna_options="--probabilistic --consistency-transformation --max-diff=100 --struct-weight=200 --mea-beta 400";

##------------------------------------------------------------
## options
use Getopt::Long;
use Pod::Usage;

my $help;
my $man;
my $quiet;
my $verbose;
my $test;

my $revcompl;

my $run_locally;
my $threads;

## Getopt::Long::Configure("no_ignore_case");

GetOptions(
    "verbose" => \$verbose,
    "quiet" => \$quiet,
    "help"=> \$help,
    "man" => \$man,
    "test" => \$test,
    "revcompl" => \$revcompl,
    "run-locally" => \$run_locally,
    "threads=i" => \$threads
    ) || pod2usage(2);

pod2usage(1) if $help;
pod2usage(-exitstatus => 0, -verbose => 2) if $man;

if ($#ARGV!=0) {print STDERR "Need annotation file.\n"; pod2usage(-exitstatus => -1);}

my $joblist="$ARGV[0]";

## ------------------------------------------------------------
## main part

if (!-d $tgt_dir) {
    print STDERR "$tgt_dir does not exist. Exit.\n";
    exit -1;
}
if (!-d $tmp_dir) {
    print STDERR "$tmp_dir does not exist. Exit.\n";
    exit -1;
}

if (defined($threads)) {
    $mlocarna_options.=" --threads $threads";
}

my $rcsuf=""; ## suffix string in case of reverse complement alignment
if ($revcompl) {$rcsuf="-rc";}

if ( $run_locally ) {
    
    open (my $JOBS, "<", $joblist) || die "Cannot read from $joblist: $!";
    
    my @jobs=<$JOBS>;
    
    close $JOBS;
    
    foreach my $jobline (@jobs) {
	my @job=split /\s+/,$jobline;
	
	my $name = "$job[1]:$job[0]";
	
	if ($revcompl && (! -e "$source_dir/$name-rc.mfa")) {
	    my $cmd = $locarna_bin."reverse-complement.pl $mlocarna $source_dir/$name.mfa";
	    if ($test) {
		print "$cmd\n";
	    } else {
		system $cmd;
	    }
	    $name .= "$rcsuf";
	}

	my $cmd = "$mlocarna $source_dir/$name.mfa $mlocarna_options --tgtdir $tgt_dir/$name.dir  > $tmp_dir/$name.output 2>&1";
	
	if ($test) {
	    print $cmd."\n";
	} else {
	    system "$cmd";
	}
    }
} else {
    ## write sge job-script

    my $tmpjoblist="$tmp_dir/realign.joblist";
    my $jobscript="$tmp_dir/realign.sge";
    
    system "cp",$joblist,$tmpjoblist || die "Cannot read and copy joblist $joblist";
    
    my $num_tasks=`wc -l $tmpjoblist | cut -f1 -d' '`;
    chomp $num_tasks;
    
    open(my $OUT, ">", "$jobscript") || die "Cannot write jobscript $jobscript: $!";
    print $OUT "#!/bin/bash
#\$ -e $tmp_dir/stderr
#\$ -o $tmp_dir/stdout
#\$ -l h_vmem=4G

line=`cat $tmpjoblist | head -\$SGE_TASK_ID | tail -1`;
locus=`echo \$line | cut -f1 -d' '`;
name=\"\$chr:\$locus\"

## optionally produce reverse complement
if [ \"$rcsuf\" ne \"\" ] ; then
  if [ ! -e $source_dir/\$name$rcsuf.mfa ] ; then
    ".$locarna_bin."reverse-complement.pl $mlocarna $source_dir/\$name.mfa
  fi
  name=\$name$rcsuf
fi 

$mlocarna $source_dir/\$name.mfa $mlocarna_options --tgtdir $tgt_dir/\$name.dir  > $tmp_dir/\$name.output 2>&1;

if [ $tmp_dir != $tgt_dir ] ; then cp $tmp_dir/\$name.output $tgt_dir; fi
";
    
    close $OUT;

    my $submission_cmd = "qsub -t 1-$num_tasks $jobscript";
    print "EXEC: $submission_cmd\n";
    system($submission_cmd) unless $test;
}
## ------------------------------------------------------------
