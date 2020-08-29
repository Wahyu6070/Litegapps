base="`dirname $(readlink -f "$0")`"
chmod -R 775 $base/bin
. $base/bin/kopi
config=$base/config
tmp=$base/tmp
bin=$base/bin/$ARCH32
log=$base/make.log
loglive=$base/make_live.log
out=$base/output
script=$base/script
del $loglive
read_config() {
	getp "$1" "$config"
}


PROP_ARCH=$(read_config arch)
PROP_SDK=$(read_config sdk)
PROP_ANDROID=$(read_config android.target)
PROP_VERSION=$(read_config litegapps.version)
PROP_BUILDER=$(read_config name.builder)

case $(read_config build.status) in
6070) PROP_STATUS=official ;;
wahyu60706070) PROP_STATUS=official ;;
*) PROP_STATUS=unofficial ;;
esac

clear
printlog " "
printlog "                 LiteGapps Building"
printlog " "
printlog " "
printlog " "
printlog "ARCH : $PROP_ARCH"
printlog "SDK  : $PROP_SDK"
printlog "VERSION : $PROP_VERSION"
printlog "Codename : $(read_config codename)"
printlog "Build Date : $(date +%d-%m-%Y)"
printlog "Build Status : $PROP_STATUS"
printlog "Android Target : $PROP_ANDROID"
printlog "Builder : $PROP_BUILDER"
printlog " "
printlog " "
printlog " "

sys_gapps=$base/gapps/$PROP_ARCH/$PROP_SDK/system
ven_gapps=$base/gapps/$PROP_ARCH/$PROP_SDK/vendor

if [[ $PROP_ARCH == all || $PROP_ARCH == All ]]; then
cp -af $base/gapps/* $tmp/
elif [[ $PROP_SDK == all || $PROP_SDK == All ]]; then
cdir $tmp/$PROP_ARCH
cp -af $base/gapps/$PROP_ARCH/* $tmp/$PROP_ARCH/
else
[ -d $tmp ] && del $tmp
[ ! -d $tmp ] && cdir $tmp
cdir $tmp/$PROP_ARCH/$PROP_SDK
tmpsys=$tmp/$PROP_ARCH/$PROP_SDK/system
tmpven=$tmp/$PROP_ARCH/$PROP_SDK/vendor
test -d $sys_gapps && cp -af $sys_gapps $tmpsys || printlog "- Failed copying $sys_gapps"
test -d $ven_gapps && cp -af $ven_gapps $tmpven
fi


printlog "- Unzip"
find $tmp -name *.apk -type f | while read apkname; do
case $apkname in
*.apk)
outdir=`dirname $apkname`
while_log "$(basename $apkname)"
cdir $outdir
$bin/unzip -o $apkname -d $outdir
del $apkname
;;
esac
done >> $loglive



print "- Creating tar file"
find $tmp -type d | while read folname; do
case "$folname" in
*system)
for i1 in $(ls -1 $folname); do
    if [ -d $folname/$i1 ]; then
       for i2 in $(ls -1 $folname/$i1); do
             cd $folname/$i1
             sedlog "- Creating .tar $folname/$i1/$i2"
             tar -cf $i2.tar $i2
             del $i2
             cd /
       done
    fi
done
;;
*vendor)
for b1 in $(ls -1 $folname); do
    if [ -d $folname/$b1 ]; then
       for b2 in $(ls -1 $folname/$b1); do
             cd $folname/$b1
             sedlog "- Creating .tar $folname/$b1/$b2"
             tar -cf $b2.tar $b2
             del $b2
             cd /
       done
    fi
done 
;;
esac
done


if [ $(read_config set.time) = true ] && [ $(read_config date.time) -eq $(read_config date.time) ]; then
printlog "- Set Timestamp $(read_config date.time)"
setime -r $tmp/$PROP_ARCH $(read_config date.time)
fi

#
#Creating tar
#
printlog "- Creating arch.tar"
cd $tmp
sedlog "- Creating arch.tar"
$bin/tar -cf "arch.tar" *
cd /
for rmdir in $(ls -1 $tmp); do
  if [ -d $tmp/$rmdir ]; then
    sedlog "- Removing $tmp/$rmdir"
    del $tmp/$rmdir
  fi
done


compression=$(read_config compression)
lvlcom=$(read_config compression.level)
printlog "- Creating archive : $compression"
printlog "- Level Compression : $lvlcom"
cd $tmp
for archi in $(ls -1 $tmp); do
   case $compression in
     xz)
       if [ $lvlcom -lt 10 ]; then
        $bin/xz -${lvlcom}e $tmp/$archi
        del $archi
       else
       abort "xz level 1-9"
       fi
     ;;
      br | brotli)
       if [ $lvlcom -lt 10 ]; then
        $bin/brotli -${lvlcom}j $archi
        del $archi
       else
       abort "brotli level 1-9"
       fi
     ;;
     zip)
     if [ $lvlcom -lt 10 ]; then
        $bin/zip -r${lvlcom} $archi.zip $archi >> $loglive
        del $archi
       else
       abort "zip level 1-9"
       fi
     ;;
     7z | 7za | 7zip | 7zr | p7zip)
     if [ $lvlcom -lt 10 ]; then
        $bin/7za a -t7z -m0=lzma -mx=$lvlcom -mfb=64 -md=32m -ms=on $archi.7z $archi >> $loglive
        del $archi
       else
       abort "7zip level 1-9"
       fi
     ;;
     zstd | zst)
     if [ $lvlcom -lt 20 ]; then
        $bin/zstd --rm -$lvlcom $archi >> $loglive
       else
       abort "Zstd level 1-19"
       fi
     ;;
     gz | gzip | gunzip)
     if [ $lvlcom -lt 10 ]; then
        $bin/gzip -$lvlcom $archi
       else
       abort "gzip level 1-9"
       fi
     ;;
     *)
       printlog "!!! Format $compression Not support"
       sleep 4s
       exit 1
      ;;
     esac
done


printlog "- Creating MD5sum"
for t1 in $(ls -1 $tmp); do
$bin/busybox md5sum -b $tmp/$t1 | cut -d ' ' -f1 > $tmp/$t1.md5
done


printlog "- Moving files"
flashable=$base/flashable
test -d $flashable/magisk/files && del $flashable/magisk/files
test ! -d $flashable/magisk/files && cdir $flashable/magisk/files
cp -pf $tmp/* $flashable/magisk/files/
cp -pf $tmp/* $flashable/all/files/


#set module.prop
printlog "- Set module.prop"
find $flashable -name module.prop -type f | while read setmodule ; do
sed -i 's/'"$(getp name $setmodule)"'/'"Litegapps ${PROP_ARCH} ${PROP_ANDROID} ${PROP_STATUS}"'/g' $setmodule
sed -i 's/'"$(getp author $setmodule)"'/'"$PROP_BUILDER"'/g' $setmodule
sed -i 's/'"$(getp version $setmodule)"'/'"v${PROP_VERSION}"'/g' $setmodule
sed -i 's/'"$(getp versionCode $setmodule)"'/'"$(read_config litegapps.version.code)"'/g' $setmodule
sed -i 's/'"$(getp date $setmodule)"'/'"$(date +%d-%m-%Y)"'/g' $setmodule
done


#
# Zip
#

case $(read_config zip.level) in
0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9) ziplevel=$(read_config zip.level) ;;
*) ziplevel=1 ;;
esac


#Magisk Module
test ! -d $out && cdir $out
zipname=`echo "LiteGapps-$PROP_ARCH-$PROP_ANDROID-$(date +%d%m%Y)-${PROP_STATUS}[Magisk Module]"`
printlog
printlog "- Creating Magisk Module"
printlog "- ZIP name  : $zipname"
printlog "- ZIP level : $ziplevel"
#del $tmp
cd $flashable/magisk
test -f "$out/$zipname.zip" && del "$out/$zipname.zip"
$bin/zip -r$ziplevel $out/"$zipname.zip" . >/dev/null
cd $base
printlog "- ZIP size  : $(du -sh $out/$zipname.zip | cut -f1)"

#all
zipname2=`echo "LiteGapps-$PROP_ARCH-$PROP_ANDROID-$(date +%d%m%Y)-${PROP_STATUS}"`
printlog
printlog "- Creating Magisk Module or non magisk module"
printlog "- ZIP name  : $zipname"
printlog "- ZIP level : $ziplevel"
del $tmp
cd $flashable/all
test -f "$out/$zipname2.zip" && del "$out/$zipname2.zip"
$bin/zip -r$ziplevel $out/"$zipname2.zip" . >/dev/null
cd $base
printlog "- ZIP size  : $(du -sh $out/$zipname2.zip | cut -f1)"
printlog "- Done"


