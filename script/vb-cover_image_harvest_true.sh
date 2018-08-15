#!/bin/sh

# Set variables
today=`date +"%Y%m%d"`
errcode=
harvestMount="/lib_content"
harvestMountPattern="lib_content0"
harvestMountType=
harvestLockDir="$harvestMount/Virgobeta"
harvestLockFile="$harvestLockDir/coverimageharvest.lock"
harvestLockFileStatus=
logFile="/tmp/vb_harvest_log-$today"
mailList='xxx@virginia.edu'
railsEnv='RAILS_ENV=search_production'
rakeCmd='/usr/bin/rake'
virgoDir='/usr/local/projects/search'

# Mail function
function Lognotify {
	case "$1" in
	
		0)	# Send success message.
			echo >> $logFile
			echo `date` >> $logFile
			echo `hostname` >> $logFile
			echo $errcode >> $logFile
			echo >> $logFile
			mail -s "Virgo cover harvest script completed successfully." $mailList < $logFile
			;;
		
		1)	# Send error if script aborts.
			echo >> $logFile
			echo `date` >> $logFile
			echo `hostname` >> $logFile
			echo $errcode >> $logFile
			echo >> $logFile
			mail -s "Virgo cover harvest script aborted. Please check message for details." $mailList < $logFile
			;;

		2)	# Send error if errors detected after script completes.
			echo >> $logFile
			echo `date` >> $logFile
			echo `hostname` >> $logFile
			echo $errcode >> $logFile
			echo >> $logFile
			mail -s "Virgo cover harvest script completed successfully, but minor errors detected." $mailList < $logFile
			;;

	esac
}

## check that lockfile exists
#if [ ! -f $harvestLockFile ]
#	then
#		errcode="Could not locate lockfile. Aborting script"
#		Lognotify 1
#		exit 1
#fi

# Create the lockfile if it does not exist.
[ -f $harvestLockFile ] || echo 0 > $harvestLockFile
if [ $? -ne 0 ] ; then
	errcode="Unable to create lockfile - check '$harvestLockFile'"
	Lognotify 1
	exit 1
fi

# confirm that lockfile is mounted on NFS filesystem
harvestMountType=`/bin/mount | grep $harvestMountPattern | awk '{print $5;}'`
if [ $harvestMountType != nfs -a $harvestMountType != NFS ]
	then 
		errcode="Harvest directory not NFS-mounted. Aborting script."
		Lognotify 1
		exit 1
fi

# check status of lockfile
## 0 = no other system is running harvest
## 1 = another system started harvest 
harvestLockFileStatus=`cat $harvestLockFile`
if [ $harvestLockFileStatus != 0 ]
	then
	errcode="Cannot confirm harvest script status from lockfile. Aborting script."
	Lognotify 1
	exit 1
fi

# Write to lockfile
echo 1 > $harvestLockFile
if [ $? -ne 0 ]
	then   
	  errcode="Unable to edit lockfile. Please check $harvestLockFile; aborting script."
	  Lognotify 1
	  exit 1
fi

# If we made it this far, all is OK to proceed
# Run harvest script
echo >> $logFile
echo `date` >> $logFile
echo "Harvest script standard out:" >> $logFile
echo >> $logFile
cd $virgoDir >> $logFile

if [ $? -ne 0 ] ; then
	errcode="Unable to change to $virgoDir. Aborting script."
	Lognotify 1
	exit 1
fi

$rakeCmd $railsEnv cover_images:harvest[true] >> $logFile

if [ $? -ne 0 ]
	then   
	  errcode="Harvest script failed with error $?. Aborting script."
	  Lognotify 1
	  exit 1
fi


# Remove lock from lockfile
echo 0 > $harvestLockFile

if [ $? -ne 0 ]
	then   
	  errcode="Script complete, but unable to edit lockfile after completion. Please check $harvestLockFile."
	  Lognotify 2
	  exit 0
fi

# Send success message and exit
errcode="Success!"
Lognotify 0
exit 0


