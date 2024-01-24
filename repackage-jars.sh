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

#hilla-maven-plugin

version="24.4.0.alpha2"
local=~/.m2/repository/com/vaadin
base=https://tools.vaadin.com/nexus/content/repositories/vaadin-prereleases/com/vaadin
ns=com.vaadin

scr=`readlink -f "$0"`
dir=`dirname $scr`/hack

mvnInstallFile() {
  echo "Installing $1 in $L/$3/$version/$1"
  mvn -q install:install-file \
    -Dfile=$1 \
    -DpomFile=$2
}

computeVars() {
  if expr $1 : ".*hilla" > /dev/null; then
    P=$base/hilla
    N=$ns.hilla
    L=$local/hilla
  else
    P=$base
    N=$ns
    L=$local
  fi
}

renameArtifact() {
  echo "Renaming $1 to $2"
  ns1=`echo $1 | cut -d : -f1`
  art1=`echo $1 | cut -d : -f2`
  ns2=`echo $2 | cut -d : -f1`
  art2=`echo $2 | cut -d : -f2`

  mv META-INF/maven/$ns1 META-INF/maven/$ns2
  mv META-INF/maven/$ns2/$art1 META-INF/maven/$ns2/$art2

  perl -pi -e 's|<groupId>'$ns1'</groupId>|<groupId>'$ns2'</groupId>|' META-INF/maven/plugin.xml META-INF/maven/$ns2/$art2/plugin-help.xml
  perl -pi -e 's|<artifactId>'$art1'</artifactId>|<artifactId>'$art2'</artifactId>|' META-INF/maven/plugin.xml META-INF/maven/$ns2/$art2/plugin-help.xml
  perl -pi -e 's|<goalPrefix>hilla</goalPrefix>|<goalPrefix>vaadin</goalPrefix>|' META-INF/maven/plugin.xml META-INF/maven/$ns2/$art2/plugin-help.xml
  perl -pi -e 's|hilla:|vaadin:|g' META-INF/maven/plugin.xml META-INF/maven/$ns2/$art2/plugin-help.xml

  perl -pi -e 's|artifactId='$art1'|artifactId='$art2'|' META-INF/maven/$ns2/$art2/pom.properties
  perl -pi -e 's|groupId='$ns1'|groupId='$ns2'|' META-INF/maven/$ns2/$art2/pom.properties

  perl -0777 -pi -e 's|(<groupId>)'$ns1'(</groupId>\s*<artifactId>)'$art1'(</artifactId>)|${1}'$ns2'${2}'$art2'${3}|ms' META-INF/maven/$ns2/$art2/pom.xml
}


for artifact in $artifacts; do
  cd $dir

  computeVars $artifact

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
    mvnInstallFile $file $file $artifact
  else
    file=$artifact-$version.jar
    curl -s -o ../$file $P/$artifact/$version/$file
    jar -xf ../$file
    if [ $artifact = hilla-maven-plugin ]; then
      old=$N:$artifact
      N=vaadin.com
      artifact=vaadin-maven-plugin
      file=$artifact-$version.jar
      renameArtifact $old $N:$artifact
    else
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
      echo "Creating $file"
    fi
    echo "Creating $file"
    jar -cf ../$file .
    mvnInstallFile ../$file META-INF/maven/$N/$artifact/pom.xml $artifact
  fi
done