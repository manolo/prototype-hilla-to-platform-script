set -e

artifacts="
vaadin-spring-boot-starter
vaadin-bom
vaadin-core-internal
vaadin-core
vaadin-internal
vaadin
hilla-bom
hilla-react
hilla
vaadin-dev
"

# hilla-dev
# artifacts=""

version="24.4.0.alpha2"
local=~/.m2/repository/com/vaadin
base=https://tools.vaadin.com/nexus/content/repositories/vaadin-prereleases/com/vaadin
ns=com.vaadin

scr=`readlink -f "$0"`
dir=`dirname $scr`/hack

install() {
  mvn -q install:install-file \
    -Dfile=$1 \
    -DpomFile=$2
}

for artifact in $artifacts; do
  if expr $artifact : ".*hilla" > /dev/null; then
    P=$base/hilla
    N=$ns.hilla
    L=$local/hilla
  else
    P=$base
    N=$ns
    L=$local
  fi

  cd $dir

  echo "Repackaging $artifact $file $folder"
  folder=tmp_$artifact
  rm -rf $folder
  mkdir -p $folder
  cd $folder

  if expr $artifact : ".*-bom" > /dev/null; then
    file=$artifact-$version.pom
    curl -s -o $file $P/$artifact/$version/$file
    if [ -f ../$artifact/$file ]; then
      cp ../$artifact/$file $file
    fi
    install $file $file
  else
    file=$artifact-$version.jar
    curl -s -o ../$file $P/$artifact/$version/$file 
    jar -xf ../$file
    for i in `find . -type f`; do
      # echo "Processing $i ../$artifact/$i"
      if [ -f ../$artifact/$i ]; then
        c=`wc -c ../$artifact/$i | awk '{print $1}'`
        if [ $c -eq 0 ]; then
          echo "Removing $i"
          rm $i
        else
          echo "Replacing $i"
          rm $i
          cp ../$artifact/$i $i
        fi
      fi
    done
    jar -cf ../$file .
    echo "Installing $file in $L/$artifact/$version/$file"
    install ../$file META-INF/maven/$N/$artifact/pom.xml
  fi
done