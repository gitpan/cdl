#!/usr/bin/perl
use strict;
# Author : Basant Kumar Kukreja
# This Script is mostly useful for used by a bash script.

my $VERSION = 1.0;

#my $CdOption = "/d"; # For Windows
my $CdOption = "";
my $Extension = ".sh" ; # For windows it should be .bat"
#my $DirSep = "\\"; # For Windows
my $DirSep = "/"; # Override for Unix

my $CDLOGVar = $ENV{"CDLOG"};
my $BashVersion_Major = 1;

# Examples :
# cdl fastcgi will search the directory having fastcgi
# cdl -d fastcgi will search the directory having fastcgi buf from the 
# current path
# cdl -c : to clean the $CDLOG ( removing unused item )


sub GetBashVersion
{
	my $BashVersion = $ENV{BASH_VERSION};
	if ( $BashVersion =~ m/(\d)\.(\d+)/ )
	{
		$BashVersion_Major = $1;
	}
	#print "BashVersion = $BashVersion_Major\n";
}

sub GetCdCommandLine
{
	my ( $ReadOpt, $FileNameList ) = @_;
	my $CommandLine;
	if( $ReadOpt == 0 )
	{
		$CommandLine = "";
	}
	else
	{
		my $FileName = $$FileNameList[$ReadOpt - 1]; 
		chomp $FileName;
		#$CommandLine = "dirs -c >/dev/null 2>&1 \; pushd $FileName > /dev/null \n";
		#$CommandLine = "builtin cd $FileName \n";
		# Don't use builtin command as this directory entry will not be
		# present in tail so cdl -? will not show this entry in tail.
		# Fixed this issue.
		$CommandLine = "cd $FileName \n";
	}
	return $CommandLine;
}

sub GenCommandLine
{
	my ( $ReadOpt, $CommandLineRef, $FileNameList , $RegExp ) = @_;
	my $CommandLine = "";
	my $ReadOptInp = $ReadOpt;
	chomp $ReadOpt;
	$ReadOpt =~ s/^\s*//g;
	$ReadOpt =~ s/\s*$//g;
	if ( $ReadOpt =~ m/\$(\d+)/ )
	{
		my @Words = split( /\s/, $ReadOpt);
		my $item;
		foreach $item ( @Words )
		{
			#if ( $item =~ m/^(\$(\d+))(.*)/ )
			# Changed on 07/05/2002 as I wanted to match $\d+ 
			# at any place rather than beginning of word
			if ( $item =~ m/^(.*)(\$(\d+))(.*)/ )
			{
				my $Beginning = $1;
				my $DirNo = $3;
				my $Resword = $4;
				my $DirName = $$FileNameList[$DirNo - 1 ];
				chomp $DirName;
				$DirName =~ s/\s*$//g;
				$DirName =~ s/^\s*//g;
				$DirName =~ s/\s*$//g;
				# Take care of space in directories
				if( $DirName =~ m/\s/ )
				{
					$DirName = "\"$DirName\"";
				}
				$item = "$Beginning$DirName$Resword";
			}
			$CommandLine .= $item;
			$CommandLine .=  " ";
		}
		print "$CommandLine\n";
		if ( $BashVersion_Major > 1 )
		{
			$CommandLine =~ s/\s*$//g;
			$CommandLine = "$CommandLine \; CDORGCMD=\"cdl $RegExp\"\; history -s $CommandLine";
		}
	}
	else
	{
		$CommandLine = GetCdCommandLine ( $ReadOpt, $FileNameList );
		print "$CommandLine\n";
		if ( $BashVersion_Major > 1 )
		{
			$CommandLine =~ s/\s*$//g;
			$CommandLine = "$CommandLine ; CDORGCMD=\"cdl $RegExp\"\; history -s cd $$FileNameList[$ReadOpt - 1]" if ( $CommandLine ne "" );
		}
	}
	$$CommandLineRef = $CommandLine;
	print "CommandLine = $CommandLine\n";
}

sub SaveCmdToBatchFile
{
	my ( $FileName , $CmdLine ) = @_;
	my $OutHandle;
	open ( OutHandle, ">$FileName$Extension");
	print OutHandle "$CmdLine";
	close OutHandle;
}

sub PrintAndAskUseOption
{
	my ( $FileName , $FileNameList , $RegExp) = @_;
	my $nCount = $#$FileNameList;
	my $nIndex = 0;
	my $nPrintIndex = 0;
	my @NewFileList;
	for ( $nIndex = 0; $nIndex <= $nCount; ++$nIndex )
	{
		my $nIndex1 = $nIndex + 1;
		my $DirName = $$FileNameList[$nIndex];
		my $bPrintLine= 1;
		chomp $DirName;
		if ( $RegExp ne "" )
		{
			#print "RegExp = $RegExp\n";
			my $DirNameMod = $DirName;
			chomp $DirNameMod;
			$DirNameMod =~ s/\s*$//g;
			$bPrintLine= 0 unless ( $DirNameMod =~ m/$RegExp/i );
			#$bPrintLine= 0 unless ( -d $DirNameMod );
			#print( "PrintLine = $bPrintLine\n");
		}
		if( $bPrintLine )
		{
			++$nPrintIndex;
			#print "$nPrintIndex ----> $DirName ( $nPrintIndex )\n";
			print "$nPrintIndex ----> $DirName <--- $nPrintIndex \n";
			push @NewFileList, $DirName
		}
	}
	print "\nEnter directory Option/Command : ";
	my $ReadOption;
	my $CmdLine;
	my $ReadOpt = <STDIN>;
	GenCommandLine ( $ReadOpt, \$CmdLine, \@NewFileList, $RegExp );
	SaveCmdToBatchFile ( $FileName, $CmdLine );
}

sub DebugPrint
{
	#print @_;
}

sub HandleDotDot
{
	my ($FileName, $RegExp , $NextOpt ) = @_;
	my $nNoOfSubDir = 1;
	# Join the next argument in Regular expression
	$RegExp .= $NextOpt;

	SaveCmdToBatchFile ( $FileName, "" );
	if ( $RegExp =~ m/^\.\.\s*(\d+)/ )
	{
		$nNoOfSubDir = $1;
	}
	my $Command = "cd ";
	my $nIndex;
	for( $nIndex = 0; $nIndex < $nNoOfSubDir; ++$nIndex)
	{
		$Command .= ".." . $DirSep ;
	}
	#DebugPrint " nEntries Command = $Command\n";
	print "$Command\n";
	SaveCmdToBatchFile ( $FileName, $Command);
}

sub ShowTailEntries
{
	my ($FileName, $RegExp , $NextOpt ) = @_;
	my $nEntries = 10;
	my $PromptInput = 0;
	my $ReadOpt = 1;
	SaveCmdToBatchFile ( $FileName, "" );
	if ( $RegExp eq "-" )
	{
		$nEntries = 1;
	}
	elsif ( $RegExp =~ m/^-(\d*)(\?)?/ )
	{
		#print "First = $1 Second = $2\n";
		if( $1 ne "" )
		{
			# Add 1 so that it ignores current directory
			$nEntries = $1 + 1;
		}
		if( $2 eq "?" )
		{
			$PromptInput = 1;
		}
	}
	else 
	{
		print "Unknow design Option \n";
		SaveCmdToBatchFile ( $FileName, "" );
		return;
	}
	my $Command = "tail -$nEntries $FileName";
	DebugPrint " Entries = $nEntries Command = $Command\n";
	my $Res = qx ( $Command );
	my @ResultLines = split( /\n/, $Res );
	@ResultLines = reverse @ResultLines;
	return if ( $#ResultLines == -1 );
	if( $PromptInput )
	{
		PrintAndAskUseOption ( $FileName, \@ResultLines );
	}
	else
	{
		my $CommandLine = GetCdCommandLine( $ReadOpt, \@ResultLines );
		print "$CommandLine\n";
		SaveCmdToBatchFile ( $FileName, $CommandLine );
	}
}

sub CleanCDLog
{
	my ( $FileName ) = @_;
	my $InpHandle;
	unless ( open ( InpHandle, "$FileName") )
	{
		die "Unable to Open $FileName\n";
	}
	my @FileLinesInp = <InpHandle> ;
	close InpHandle;
	
	my %TempHash;
	my @UniqLines;
	my $nItem;
	foreach $nItem ( reverse @FileLinesInp )
	{
		unless($TempHash{$nItem}++) { push(@UniqLines,$nItem); }
	}
	@UniqLines = reverse @UniqLines;
	my @NewLines; 
	my $item ;
	foreach $item ( @UniqLines )
	{
		chomp $item;
		if ( -e "$item" )
		{
			push @NewLines,"$item\n";
		}
		else
		{
			print "Removing non existent file $item from Log ++\n";
		}
	}

	my $OutHandle;
	if ( open ( OutHandle, ">$FileName") )
	{
		print OutHandle @NewLines;
		close OutHandle;
	}
	else
	{
		print "Unable to open $FileName for writing\n";
	}
}

sub PrintHelp
{
	my $BeginHelpText = <<ENDHELPTEXT
	cdl abc : will search in CDLOG any file/dir having abc
	cdl <regexp> : will search in CDLOG any file/dir which matches 
                   regular expression regexp.
	cdl -h : to print this help
	cdl -c : to clean the \$CDLOG ( removing unused item )
	cdl -d abc : It is similar to cdl abc but it will search from
               current directory
	cdl -? : This will print last 10 entries.
	cdl -n? : This will print last n entries.

	On execution when it prints "Enter directory Option/Command" we can give
	any shell command. In the command we can use \$n  to replace
	the directory name. e.g command : diff \$5 \$6 will run the
	diff command with directory entry 5 and directory entry 6.
ENDHELPTEXT
;
	print  "$BeginHelpText";
}

sub ShowDirList
{
	my ($FileName, $RegExp , $NextOpt ) = @_;
	return unless ( -e "$FileName" );
	my $InpHandle;
	$FileName =~ s/\\/\//g;

	if ( $RegExp =~ m/^\-/ )
	{
		if ( $RegExp eq "-d" )
		{
			use Cwd;
			my $WorkDir = getcwd();
			chomp $WorkDir;
			# Search from the current Directory
			$RegExp = "$WorkDir/.*$NextOpt";
			#print "NewRegExp = $RegExp\n";
		}
		elsif ( $RegExp eq "-c" )
		{
			CleanCDLog ( $FileName );
			return;
		}
		elsif ( $RegExp eq "-h" )
		{
			PrintHelp ( );
			return;
		}
		else
		{
			ShowTailEntries ( @_ );
			return ;
		}
	}
	if ( $RegExp =~ m/^\.\./ )
	{
		HandleDotDot( @_);
		return ;
	}
	unless ( open ( InpHandle, "$FileName") )
	{
		die "Unable to Open $FileName\n";
	}
	my @FileLinesInp = <InpHandle> ;
	close InpHandle;
	
	my %TempHash;
	my @UniqLines;
	my $nItem;
	foreach $nItem ( reverse @FileLinesInp )
	{
		unless($TempHash{$nItem}++) { push(@UniqLines,$nItem); }
	}
	@UniqLines = reverse @UniqLines;
	#print "Uniq Lines = @UniqLines\n";
	close InpHandle;
	my $OutHandle;
	if ( open ( OutHandle, ">$FileName") )
	{
		print OutHandle @UniqLines;
		close OutHandle;
	}
	else
	{
		print "Unable to open $FileName for writing\n";
	}
	@UniqLines = sort @UniqLines;
	GetBashVersion();
	PrintAndAskUseOption ( $FileName, \@UniqLines , $RegExp);
}


#print ( "CDLogVar = $CDLOGVar\n" ); 
ShowDirList( $CDLOGVar , @ARGV );

__END__

=head1 NAME

cdlintern.pl - A perl utility to display the different visited directories.

=head1 SYNOPSIS

   cdl var : will search in CDLOG any file/dir name containing var
   cdl <regexp> : will search in CDLOG any file/dir which matches
   		regular expression regexp.
   cdl -h : to print this help
   cdl -c : to clean the $CDLOG ( removing unused item )
   cdl -d abc : It is similar to cdl abc but it will search from
       current directory
   cdl -? : This will print last 10 entries.
   cdl -n? : This will print last n entries.

=head1 DESCRIPTION

It is designed to be used from bash. The idea is that on every directory change
by cd command, we save the directory into a log file. Any time, to go back to a
previous visited directory, we can use cdl command with directory name by
regular expression. 

To be used from bash, we have to define two function named cd and cdl. My
functions are attached in this documentation.  Log file name is given by a
environment variable CDLOG. By default shell function cd sets the CDLOG to
$HOME/tmp/cdsave/`hostname`cdlog.txt. If directory doesn't exist then it creates it.

On execution when it prints "Enter directory Option/Command" . When we
enter the number, it changes the directory to the directory. If we don't
enter the number, it treats it as a shell command and tries to execute it.
The usefulness of the this feature is that in shell command we can refer
the corresponding directories by their number using $5.  In the command we
can use $n  to replace the directory name. e.g command : diff $5 $6 will
run the diff command with directory entry 5 and directory entry 6.

Advantages over pushd/popd/dirs :

=over

=item *
It saves the visited directoy in log file so it could remain save for days and
months until you delete it. Also it remain valid for several invocation of shell.

=item *
Any shell operation ( e.g copying/moving files) between directories with deep nesting
is much simpler.

=back

=head1 CONFIGURATION 

Copy this script anywhere in the directory which is inside PATH. I prefer to
put it in ~/bin directory.


Configuring .bashrc: Here are the bash functions which need. To use it from
.bashrc we need to declare the two functions.

=begin html
<pre>

=end html

function cd ()
{
        set +u
        CDLOG_File=~/tmp/cdsave/cdlog`hostname`.txt
        if [ -z "$CDLOG"  ]; then
                export CDLOG=$CDLOG_File
                touch $CDLOG
                chmod 666 $CDLOG
        fi
        CDLOG_Dir=`dirname $CDLOG_File`
        if [ ! -d  "$CDLOG_Dir" ]; then
                mkdir -p ~/tmp/cdsave
        fi
        if [ $#  -eq 0 ]
        then
                builtin cd $HOME
        else
                builtin cd "$*"
        fi
        pwd >>$CDLOG
        unset CDLOG_File
        unset CDLOG_Dir
}

function cdl ()
{
        set +u
        if [ -z "$CDLOG" ]
        then
                cd "."
        fi
        if test -e ~/bin/cdlintern.pl
        then
                #echo "Running ~/bin/cdlintern.pl";
                perl ~/bin/cdlintern.pl $*
        else
                #echo "Running cdlintern.pl in path ";
                perl -S cdlintern.pl $*
        fi
        if [ -f "$CDLOG.sh" ]
        then
                source "$CDLOG.sh"
        else
                echo "$CDLOG.sh doesn't exist"
        fi
}
export BASH_VERSION
# Endif of entries in .bashrc

=begin html
</pre>

=end html

=head1 EXAMPLES 


=over

=item
[~] $ cd /tmp/

=item
[/tmp] $ cd /var

=item
[/var] $ cdl


=item
1 ----> /tmp <--- 1

=item
2 ----> /var <--- 2

=item
Enter directory Option/Command : 1

=item
cd /tmp


=item
CommandLine = cd /tmp ; CDORGCMD="cdl "; history -s cd /tmp

=item
[/tmp] $ cd /usr/bin

=item
[/usr/bin] $ cd /usr/local/bin

=item
[/usr/local/bin] $ cdl bin$

=item
1 ----> /usr/bin <--- 1

=item
2 ----> /usr/local/bin <--- 2


=item
Enter directory Option/Command : 1

=item
cd /usr/bin


=item
CommandLine = cd /usr/bin ; CDORGCMD="cdl bin$"; history -s cd /usr/bin

=item
[/usr/bin] $ cdl bin$

=item
1 ----> /usr/bin <--- 1

=item
2 ----> /usr/local/bin <--- 2

=item
Enter directory Option/Command : ln -s $1/customapp $2/myapp

=item
ln -s /usr/bin/customapp /usr/local/bin/myapp

=item
CommandLine = ln -s /usr/bin/customapp /usr/local/bin/myapp ; CDORGCMD="cdl bin$"; history -s ln -s /usr/bin/customapp /usr/local/bin/myapp

=item
[/usr/bin] $

=back


=head1 ENVIRONMENT VARIABLE

CDLOG contains the name of the log file where it saves the visited directories.
The schell function cd set's it to default ~/tmp/cdsave/cdlog`hostname`.txt.
You can set it to /tmp/cdlog.txt for simplicity.

=head1 PREREQUISITES

Currently used under bash. 

=head1 COREQUISITES

=pod OSNAMES

any

=pod SCRIPT CATEGORIES

CPAN/Administrative
CPAN

=cut 
