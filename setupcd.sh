function cd () 
{ 
	set +u
	CDLOG_File=~/tmp/cdsave/cdlog`hostname`.txt
	#echo "File is $CDLOG_File"
	if [ -z "$CDLOG"  ]; then
		export CDLOG=$CDLOG_File
		touch $CDLOG
		chmod 666 $CDLOG
	fi
	CDLOG_Dir=`dirname $CDLOG_File`
	#echo "Dir is $CDLOG_Dir"
	if [ ! -d  "$CDLOG_Dir" ]; then
		mkdir -p ~/tmp/cdsave
	fi
	if [ $#  -eq 0 ]
	then
		builtin cd $HOME
	else
		#echo "now I will cd to $HOME";
		builtin cd "$*"
	fi
	pwd >>$CDLOG
	unset CDLOG_File
	unset CDLOG_Dir
	#echo "Hello at End"
}
	
function cdl () 
{
	set +u
	if [ -z "$CDLOG" ]
	then
		cd "."
		#source ~/bin/mycd.sh "."
	fi
	if test -e ~/bin/cdlintern.pl 
	then
		#echo "Running ~/bin/cdlintern.pl";
		perl ~/bin/cdlintern.pl $*
	else
		#echo "Running cdlintern.pl in path ";
		#which cdlintern.pl
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
