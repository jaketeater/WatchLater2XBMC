WatchLater2XBMC
===============

WatchLater2XBMC is a bash script that downloads the videos in your YouTube Watch Later list and sends them to XBMC as a tv show episode (for the "YouTube" tv show).

WatchLater2XBMC checks your Watch Later list and uses youtube-dl to download the vidoes.  Then it scrapes YouTube for the details of each video and generates an (tv episode) .nfo file.  Once the file has been downloaded and the .nfo file is in place, the script tells XBMC to scan for new files and sends a notification message.  The script can be run as a cronjob.

1.  To install, create a directory with your TV Shows called YouTube and copy the tvshow.nfo to the that directory.
2.  Copy WatchLater2XBMC.sh and make it executable.  
3.  Configure WatchLater2XBMC.sh by editing it with the editor of your choice.  Be sure to set the TARGET_PATH as the directory you created in step one. 
4.  Create a cronjob to execute the script in the desired frequency.
