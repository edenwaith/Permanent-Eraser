#!/bin/sh
# test script for srm

SRM="src/srm -sv"

# test different file types

testremove()
{
    $SRM -rf "$1"
    if [ -e "$1" ] ; then
	echo could not remove $1
	exit 1
    fi
}

echo "TEST" > test.file
if [ ! -f test.file ] ; then
    echo could not create test file
    exit 1
fi

ln -s test.file test.symlink
if [ ! -L test.symlink ] ; then
    echo could not create symlink
    exit 1
fi
testremove test.symlink

echo "TEST" > test.file2
chmod 000 test.file2
testremove test.file2

rm -rf test.dir
mkdir test.dir
if [ ! -d test.dir ] ; then
    echo could not mkdir test.dir
    exit 1
fi

echo "TEST2" > test.dir/file2
cd test.dir
ln -s file2 link2
if [ ! -L link2 ] ; then
    echo link2
    exit 1
fi
cd ..

testremove test.dir

I=`whoami`

if [ "$I" = root ] ; then

    mkdir test.dir2
    echo "TEST" > test.dir2/test.file
    chmod 000 test.dir2/test.file
    chmod 000 test.dir2
    testremove test.dir2

    mknod test.char c 1 1
    if [ ! -c test.char ] ; then
	echo could not mknod test.char
	exit 1
    fi
    testremove test.char

    mknod test.block b 1 1
    if [ ! -c test.block ] ; then
	echo could not mknod test.block
	exit 1
    fi
    testremove test.block

fi

mkfifo test.fifo
if [ ! -p test.fifo ] ; then
    echo could not create fifo
    exit 1
fi
testremove test.fifo

testremove test.file
if [ -f test.file ] ; then
    echo could not remove test file
    exit 1
fi

# test directory symlink
mkdir test.dir
cd test.dir
echo test > test.file
ln -s test.file test.link
mkdir -p /tmp/doj
echo test2 > /tmp/doj/test.file2
ln -s /tmp/doj doj
cd ..
testremove test.dir
if [ ! -f /tmp/doj/test.file2 ] ; then
    echo srm deleted /tmp/doj/test.file2 instead of directory symlink
    exit 1
fi

# test file sizes

BS=123
SRC=/dev/zero # /dev/urandom

if [ ! -c $SRC ] ; then
    echo $SRC not present or no char device
    exit 1
fi

testsrm()
{
    if [ ! -f $F ] ; then
	echo failed to create $F
	exit 1
    fi
    ls -l $F
    if ! $SRM $F ; then
	echo failed to secure remove $F
	exit 1
    fi
    if [ -f $F ] ; then
	echo srm was not able to remove $F
	exit 1
    fi
}

F="0.tst"
touch $F
testsrm

# test until ~5GiB
for i in 1 22 333 4444 55555 666666 7777777 44444444 ; do
    F="$i.tst"
    dd if=$SRC of=$F bs=$BS count=$i 2> /dev/null
    testsrm
done

echo all tests successfull
exit 0
