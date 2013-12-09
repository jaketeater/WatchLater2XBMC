#!/bin/bash

#Configuration
TARGET_PATH=""	#Ex /media/XBMC_Library/YouTube
GOOGLE_EMAIL=''	#Ex: example@gmail.com
GOOGLE_PASSWORD='' 
APP_NAME="" 	#You can make this up.  Its for Google's logs
DEVELOPER_KEY="" 	#You can get this here: https://code.google.com/apis/youtube/dashboard/gwt/index.html

#To get notifications in XBMC and allow this script to update XBMC's library, you need to "Allow control of XBMC via HTTP" (In XBMC go to Settings->Services->Webserver)
XBMC_IP_ADDRESS="" 	#The IP address of your XBMC box - used to send a command to update the library and send a notification after a video has been added
XBMC_JSON_PORT="" 	#The port that is set in XMBC under Settings->Services->Webserver->Port 
XBMC_LOGIN=""	#Your username from the page above
XBMC_PASS=""	#Your password from the page above
#END Configuration

#Generate an authorization token.
AUTH_TOKEN=$(curl --silent https://www.google.com/accounts/ClientLogin --data-urlencode Email=$GOOGLE_EMAIL --data-urlencode Passwd=$GOOGLE_PASSWORD -d accountType=GOOGLE -d source=$APP_NAME -d service=youtube | grep -oP "(?<=Auth=).*" )

#This function takes one perameter - a YouTube video ID (ex: 5z1fSpZNXhU).  It then sets a few virables with information pertaining to that video, as well as creating the .nfo file's content.
function scrape_info {
	VIDEO_XML="$(curl -s http://gdata.youtube.com/feeds/api/videos/$1?v=2 | xmllint --format -)"
	TITLE="$(echo "$VIDEO_XML" | grep -oP '(?<=<title>).*(?=\</title)')"
	RATING="$(echo "$VIDEO_XML" | grep -oP "(?<=rating average=\").*(?=\" max)")"
	DESCRIPTION="$(echo "$VIDEO_XML" | tr -d "\n\r" | awk -F 'media:description' '{for (i=3; i<=NF; i++) {print $2}}' | grep -oP "(?<= type=\"plain\">).*(?=\</)")"
	THUMB="http://i1.ytimg.com/vi/$1/hqdefault.jpg"
	NAME="$(echo "$VIDEO_XML" | grep -oP "(?<=<name>).*(?=</name>)")"
	PUBLISHED="$(echo "$VIDEO_XML" | grep -oP "(?<=<published>).*(?=T)")"

#	YEAR="$(date +%Y -d "$PUBLISHED")"
#	DAY_OF_YEAR="$(date +%j -d "$PUBLISHED")"

# 	Uncomment above and comment below to use the date the video was published to set the season and episode, instead of the date the video was downloaded
        YEAR="$(date +%Y)"
	DAY_OF_YEAR="$(date +%j)"

	DURATION="$(echo "$VIDEO_XML" | grep -oP "(?<=<yt:duration seconds=\").*(?=\"/>)")"
	INFO="$(echo "<episodedetails>
		<title>$TITLE</title>
		<rating>$RATING</rating>
		<season>$YEAR</season>
		<episode>$DAY_OF_YEAR</episode>
		<plot>$DESCRIPTION</plot>
		<thumb>$THUMB</thumb>
		<credits>$NAME</credits>
		<aired>$PUBLISHED</aired>
		<premiered>$PUBLISHED</premiered>
		<studio>Youtube</studio>
		 <fileinfo>
		       <durationinseconds>$DURATION</durationinseconds>
		</fileinfo>
	</episodedetails>")"
}

while [ $(curl --silent --header "Authorization: GoogleLogin auth=$AUTH_TOKEN" "http://gdata.youtube.com/feeds/api/users/JakeAmandaTeater/watch_later?v=2" | grep -oP "(?<=\<openSearch:totalResults>)[0-9]*?(?=\</openSearch:totalResults>)") -gt 0 ]
do
	#Download the Watch Later playlist
	WATCH_LIST_XML=$(curl --silent --header "Authorization: GoogleLogin auth=$AUTH_TOKEN" "http://gdata.youtube.com/feeds/api/users/JakeAmandaTeater/watch_later?v=2")

	#Extract the Playlist ID from the Watch Later XML file.  This ID is used to add the video back to the play list in case of an error
	PLAYLIST_ID=$(echo "$WATCH_LIST_XML" | grep -oP "(?<=yt:playlistId>).*?(?=\</yt:playlistId)")

	#Extract the Entry ID for the video, this ID is used to delete the video's playlist entry.
	ENTRY_ID=$(echo "$WATCH_LIST_XML" | tr -d "\n\r" | grep -oP "(?<=watch_later:).*?(?=\</id)" | head -1)

	#Extract the VID (ex: 5z1fSpZNXhU).  This is passed along to the scrape_info function to find the information pertaining to the specific video
	VID=$(echo "$WATCH_LIST_XML" | grep -oP "(?<=media:player url='http://www.youtube.com/watch\?v=).*?(?=&amp;feature)" | head -1)

	#Delete the playlist entry.  This is done before starting the download, just in case to prevent the same video from being downloaded twice. (For example, if the script is run as a cronjob and the video is long) 
	curl -X DELETE -H "DELETE /feeds/api/playlists/watch_later/$ENTRY_ID" -H "Host: gdata.youtube.com" -H "Content-Type: application/atom+xml" -H "Authorization: GoogleLogin auth=$AUTH_TOKEN" -H "GData-Version: 2" -H "X-GData-Key: key=$DEVELOPER_KEY" https://gdata.youtube.com/feeds/api/playlists/watch_later/$ENTRY_ID		

	#Use the scrape_info function to set the variables that pertain to the video
	scrape_info "$VID"

	#youtube-dl does not allow setting a target directory.  So the script will enter the target directory and then download the file and create the .nfo file
	cd $TARGET_PATH 

	#Download the video with youtube-dl, prefering formats in this order: 37/22/18
#	youtube-dl -f 37/22/18 -o "$(echo "S${YEAR}E${DAY_OF_YEAR}-VID-$VID.mp4")" $VID

	#Create the .nfo file for XBMC to scrape
	echo "$INFO" >> "$(echo "$TARGET_PATH/S${YEAR}E${DAY_OF_YEAR}-VID-$VID.nfo")"
	if [ $? -eq 0 ]
	then
		#If the download is successful, tell XBMC to scan for new files and then send a notification to XBMC.
		curl --globoff "http://$XBMC_LOGIN:$XBMC_PASS@$XBMC_IP_ADDRESS:$XBMC_JSON_PORT/jsonrpc?request={%22id%22:1,%22jsonrpc%22:%222.0%22,%22method%22:%22VideoLibrary.Scan%22}"
		TITLE_ENCODED=$(perl -MURI::Escape -e 'print uri_escape($ARGV[0]);' "$TITLE" | tr '"' "'")
		curl --globoff "http://$XBMC_LOGIN:$XBMC_PASS@$XBMC_IP_ADDRESS:$XBMC_JSON_PORT/jsonrpc?request={%22id%22:1,%22jsonrpc%22:%222.0%22,%22method%22:%22GUI.ShowNotification%22,%22params%22:{%22image%22:%22http://www.youtube.com/yt/brand/media/image/YouTube-icon-full_color.png%22,%22displaytime%22:15000,%22title%22:%22YouTube%22,%22message%22:%22The%20video%20'$TITLE_ENCODED'%20has%20been%20added%20to%20the%20YouTube%20Channel.%22}}"
	else
		#If the download fails, add the video back to the play list
		curl -X POST -H "POST /feeds/api/playlists/$PLAYLIST_ID" -H "Host: gdata.youtube.com" -H "Content-Type: application/atom+xml" -H "Authorization: GoogleLogin auth=$AUTH_TOKEN" -H "GData-Version: 2" -H "X-GData-Key: key=$DEVELOPER_KEY" --data-binary "<?xml version='1.0' encoding='UTF-8'?><entry xmlns='http://www.w3.org/2005/Atom' xmlns:yt='http://gdata.youtube.com/schemas/2007'><id>$VID</id><yt:position>1</yt:position></entry>" https://gdata.youtube.com/feeds/api/playlists/$PLAYLIST_ID
	fi
done
