#!/bin/bash

TARGET_PATH=""
GOOGLE_EMAIL=''
GOOGLE_PASSWORD=''
APP_NAME=""
DEVELOPER_KEY=""
AUTH_TOKEN=$(curl --silent https://www.google.com/accounts/ClientLogin --data-urlencode Email=$GOOGLE_EMAIL --data-urlencode Passwd=$GOOGLE_PASSWORD -d accountType=GOOGLE -d source=$APP_NAME -d service=youtube | grep -oP "(?<=Auth=).*" )

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
	WATCH_LIST_XML=$(curl --silent --header "Authorization: GoogleLogin auth=$AUTH_TOKEN" "http://gdata.youtube.com/feeds/api/users/JakeAmandaTeater/watch_later?v=2")
	ENTRY_ID=$(echo "$WATCH_LIST_XML" | tr -d "\n\r" | grep -oP "(?<=watch_later:).*?(?=\</id)" | head -1)
	VID=$(echo "$WATCH_LIST_XML" | grep -oP "(?<=media:player url='http://www.youtube.com/watch\?v=).*?(?=&amp;feature)" | head -1)
	scrape_info "$VID"
	cd $TARGET_PATH 	#youtube-dl does not allow setting a target directory.  So the script will enter the target directory and then download the file and create the .nfo file
	youtube-dl -f 37/22/18 -o "$(echo "S${YEAR}E${DAY_OF_YEAR}-VID-$VID.mp4")" $VID
	echo "$INFO" >> "$(echo "$TARGET_PATH/S${YEAR}E${DAY_OF_YEAR}-VID-$VID.nfo")"
	if [ $? -eq 0 ]
	then
		curl -X DELETE -H "DELETE /feeds/api/playlists/watch_later/$ENTRY_ID" -H "Host: gdata.youtube.com" -H "Content-Type: application/atom+xml" -H "Authorization: GoogleLogin auth=$AUTH_TOKEN" -H "GData-Version: 2" -H "X-GData-Key: key=$DEVELOPER_KEY" https://gdata.youtube.com/feeds/api/playlists/watch_later/$ENTRY_ID		
	fi
done
