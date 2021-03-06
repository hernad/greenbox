#!/bin/bash

DOCKER_BUILD_OPTS=${DOCKER_BUILD_OPTS:-}
#PROXY_DETECTED=`docker inspect --format '{{ .NetworkSettings.IPAddress }}' apt-cacher-ng`
#DOCKER_PROXY=${DOCKER_PROXY:-$PROXY_DETECTED}

if [ $# -lt 1 ] ; then
   echo "usage: $0 greenbox apps green x11 ruby"
   echo "       $0 greenbox"
   echo "envars: GREEN_PRODUCTION: (rack|vbox)"
   exit 1
fi

arg=$1
shift

DOCKER_VERSION=`cat DOCKER_VERSION`
KERNEL_VERSION=`cat KERNEL_VERSION`
GREENBOX_VERSION=`cat GREENBOX_VERSION`

sed -e "s/XBuildX/$(date +'%Y%m%d-%T %z')/" \
  -e "s/XDockerX/$DOCKER_VERSION/" \
  -e "s/XGreenBoxX/$GREENBOX_VERSION/" \
  motd.template > ./rootfs/rootfs/usr/local/etc/motd

sed -e "s/___GREEN_APPS_VER___/$(cat apps/green/VERSION)/"  \
    -e "s/___BLUE_APPS_VER___/$(cat apps/blue/VERSION)/"  \
    -e "s/___VBOX_VER___/$(cat VBOX_VERSION)/"  \
    -e "s/___DEVELOPER_VER___/$(cat apps/developer/VERSION)/"  \
    -e "s/___K8S_VER___/$(cat apps/k8s/VERSION)/"  \
    -e "s/___X11_APPS_VER___/$(cat apps/x11/VERSION)/"  \
    -e "s/___PYTHON2_VER___/$(cat apps/python2/VERSION)/"  \
     green_common.template > rootfs/green_common

cat ./rootfs/rootfs/usr/local/etc/motd && \
cp  ./rootfs/rootfs/usr/local/etc/motd  ./rootfs/isolinux/boot.msg || ( echo error && exit 1)

#docker exec apt-cacher-ng ifconfig eth0 | grep "inet addr" | awk -F: '{print $2}'

GREEN_PRODUCTION=${GREEN_PRODUCTION:-rack}

if [ "$GREEN_PRODUCTION" == "rack" ] ; then
   ISO_DEFAULT=rack
else
   ISO_DEFAULT=vbox
fi


# Get the git versioning info
GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD) && \
GITSHA1=$(git rev-parse --short HEAD) && \
DATE=$(date) && \
echo "${GIT_BRANCH} : ${GITSHA1} - ${DATE}" > GREENBOX_BUILD


ISO_APPEND="loglevel=3"

if [ -f docker_password ] ; then ## if file docker_password exists set dockerpwd
    DOCKER_PASSWORD=`cat docker_password`
    ISO_APPEND+=" dockerpwd=$DOCKER_PASSWORD"
fi

# lang=bs_BA.UTF-8"
# ISO_APPEND+=" rootpwd=root01"
ISO_APPEND+=" tz=CET-1CEST,M3.5.0,M10.5.0\/3"
ISO_APPEND+=" noembed nomodeset norestore waitusb=10 LABEL=GREEN_HDD"

echo $ISO_APPEND
sed  -e "s/{{ISO_APPEND}}/${ISO_APPEND}/" \
      -e "s/{{ISO_APPEND}}/${ISO_APPEND}/" \
      -e "s/{{ISO_DEFAULT}}/${ISO_DEFAULT}/" \
      isolinux.cfg.template > rootfs/isolinux/isolinux.cfg

while [ "$arg" ]
do

  case $arg in
      greenbox)
         docker rmi -f greenbox:$GREENBOX_VERSION
         docker build $DOCKER_BUILD_OPTS \
              --build-arg DOCKER_PROXY=$DOCKER_PROXY \
              --build-arg KERNEL_VERSION=$KERNEL_VERSION -t greenbox:$GREENBOX_VERSION .
         docker tag greenbox:$GREENBOX_VERSION greenbox:latest
         docker images greenbox | awk '{ print  $2 } ' | grep $GREENBOX_VERSION
         ret=$?
         ;;
     *)
         app=$arg
         APP_VERSION=`cat apps/${app}/VERSION`
	 rm ${app}_${APP_VERSION}.tar.xz
	 rm -rf ${app}
         docker rmi -f greenbox_app_${app}:$APP_VERSION
         docker build $DOCKER_BUILD_OPTS \
               --build-arg DOCKER_PROXY=$DOCKER_PROXY \
               --build-arg KERNEL_VERSION=$KERNEL_VERSION \
               -t greenbox_app_${app}:$APP_VERSION -f apps/${app}/Dockerfile . &&\
         docker tag greenbox_app_${app}:$APP_VERSION greenbox_app_${app}:latest
         docker images greenbox_app_${app} | awk '{ print  $2 } ' | grep $APP_VERSION
         ret=$?
         ;;

  esac

  arg=$1
  shift

done

exit $ret
