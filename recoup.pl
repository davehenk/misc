#!/usr/bin/perl -w
use strict;

# (C) 2004 dave (at) hoax (dot) ca
# ************* THIS SCRIPT HAS NO WARRANTY! **************
#
# this script works with the output from SleuthKit's fls and icat version: 3.00
# using afflib-3.3.4
#
# dont worry if you do not have the same versions because it should work unless
# the output from the commands have changed
#
# if the script does not work, please email me the debug output and
# the output from manually running fls and icat, thanks!
#
# set the recovery directory 
my $fullpath="/recover/tmp/";

# set the absolute path of fls binary
my $FLS="/usr/local/sleuthkit/bin/fls";

# set the fls options
my @FLS_OPT=("-f","linux-ext2","-pr","-m $fullpath","-s 0");

# set the path of the device to be recovered
my $FLS_IMG="/dev/device0";

# set the inode of the directory to be recovered
my $FLS_inode="1";

# set the path of the icat STDERR log
my $ICAT_LOG="/recover/icat.log";

# set the absolute path of the icat binary
my $ICAT="/usr/local/sleuthkit/bin/icat";

# set the icat options
my @ICAT_OPT=("-f","linux-ext2");

my $ICAT_IMG="$FLS_IMG";

# here we go. hold on tight!
list($FLS_inode);


sub list($) {
	#make the recovery dir
	system("mkdir","-p","$fullpath") && die "Cannot mkdir $fullpath while processing: $_";
	#run a recursive FLS on our chosen inode and regex each line
	foreach $_ (`$FLS @FLS_OPT $FLS_IMG $_[0] 2>&1`) {
		regex($_);
		#print $_;
	}
}

sub regex($) {
	#first, regex for dirs, clean 'em up, and create 'em in recovery dir
	#
	# the following regex will work on output of the format:
	# 0|/directory/file.foo.bar (deleted)|0|r/----------|0|0|0|0|0|0
	# 0|/directory/file.foo.bar|1384462|r/rrw-r--r--|1000|1000|971556|1218136846|1218136846|1225037181|0
	# 0|/directory|1392712|d/drwxr-xr-x|1000|1000|4096|1225309096|1225309096|1226059913|0
	# 0|/directory/file.foo.bar -> /directory2/file2.foo.bar|1384462|l/lrw-r--r--|1000|1000|971556|1218136846|1218136846|1225037181|0
	#
	#
	if (/(\d\|([\S\s]+)\|(\d+)\|\S\/d([\w-]{3})([\w-]{3})([\w-]{3})(\|\d+\|\d+\|\d+\|\d+\|\d+\|\d+\|\d+))/) {
		my $fulldir = $2;
		my $uid = $4; my $gid = $5; my $oid = $6;
		$fulldir =~ s/ (\(deleted(\)|\-realloc\)))$//g;
		$fulldir =~ s/ /_/g;
		$uid =~ s/-//g; $gid =~ s/-//g; $oid =~ s/-//g;
		$uid = lc($uid); $gid = lc($gid); $oid = lc($oid);
		#print "mkdir -p $fulldir\n";
		system("mkdir","-p","$fulldir") && die "Cannot mkdir $fulldir while processing: $_";
		#print "chmod u=$uid,g=$gid,o=$oid $fulldir\n";
		system("chmod","u=$uid,g=$gid,o=$oid","$fulldir") && die "Cannot chmod u=$uid,g=$gid,o=$oid $fulldir while processing: $_";
	#second, regex for files, sockets, fifos then
	#clean and dump them in recovery dir	
	} elsif (/(\d\|([\S\s]+)\|(\d+)\|\S\/(-|s|f|r)([\w-]{3})([\w-]{3})([\w-]{3})((\|\d+\|\d+\|\d+\|\d+\|\d+\|\d+\|\d+)|(\|\d+\|\d+\|\d+\|\d+\|\d+\|\d+)))/) {
		my $inode = $3;
		my $fullfile = $2;
		$fullfile =~ s/ (\(deleted(\)|\-realloc\)))$//g;
		$fullfile =~ s/ /_/g;
		#print "$ICAT @ICAT_OPT $ICAT_IMG $inode > $fullfile\n" if ($inode != 0);
		system("$ICAT @ICAT_OPT $ICAT_IMG $inode > \"$fullfile\" 2>> $ICAT_LOG") if ($inode != 0);
		#cannot use die cuz an invalid inode will kill the script
		#&& die "Cannot icat $inode into \"$fullfile\" while processing: $_"
		
	# thrid, regex for symlink, clean, and create in recovery dir
	} elsif (/(\d\|([\S\s]+)\s\-\>\s([\S\s]+)\|(\d+)\|\S\/(l)([\w-]{3})([\w-]{3})([\w-]{3})(\|\d+\|\d+\|\d+\|\d+\|\d+\|\d+\|\d+))/) {
		#print "$1\n";
		my $fullsym_dst = $2; my $fullsym_src = $3;
		$fullsym_dst =~ s/ /_/g; $fullsym_src =~ s/ /_/g;
		#print "ln -s $fullsym_src $fullsym_dst\n";
		system("ln","-s","$fullsym_src","$fullsym_dst") && die "Cannot ln $fullsym_src $fullsym_dst while processing: $_";
	} else {
		print "Unknown directory listing. File or directory NOT recovered\nDebug:\n$_[0]\n";
	}
} #that's all folks. hope y'all had fun!
