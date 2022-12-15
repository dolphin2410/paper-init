origin=$1
target=$2

if [ -d $target ]; then
    cd $target
    git init
    git remote add origin $origin
    git pull origin master
else
    git clone $origin $target
fi