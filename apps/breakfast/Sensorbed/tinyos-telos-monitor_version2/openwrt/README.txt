Doug Carlson 11/13/2012

Here's how to get a build environment set up for openwrt, as well as
some other things that I found not-straightforward to do.

Setting up the OpenWRT toolchain
--------------

- Check out 7.09 svn tag:
  svn://svn.openwrt.org/openwrt/tags/kamikaze_7.09

- Download this thing from intel and put it in the dl dir:
  http://downloadcenter.intel.com/detail_desc.aspx?ProductID=2100&DwnldID=12954&agr=Y

- Clone the linux-stable git repo into a directory called linux-2.6.21.6 
  git clone \
    git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git \
    linux-2.6.21.6

- check out the 2.6.21.6 tag 
  git checkout v2.6.21.6

- make a bzip2 file of this:
  tar -j -c linux-2.6.21.6.tar.bz2 linux-2.6.21.6

- put it into the dl directory as well.

- do a `make menuconfig` and load the configuration file
  "hinrg-testbed.config" (from this directory)

- Add the file 1000-hinrg.patch (from this directory) to the
  toolchain/gcc/patches/4.1.2 directory (under the openwrt root)

- do a `make` in the openwrt root directory
  - this is going to take a while.
  - I was able to compile the gcc/binutils toolchain for the nslu's
    OK, but it didn't compile the linux kernel correctly

Building stuff for OpenWRT
--------------

If all went well, you should now have under your openwrt root a
directory called staging_dir_armeb, containing bin, include, lib, etc. 

The g++ compiler you want to use is armeb-linux-uclibc-g++
The gcc compiler you want to use is armeb-linux-uclibc-gcc
The linker you want is aremb-linux-uclibc-ld

If you need to compile shared libraries (e.g. libpopt for
parameters-parsing), do this:
- get the source
  sudo apt-get source libpopt-dev
- from the source directory, configure automake for the NSLU
  ./configure --host=armeb-openwrt-linux-uclibc \
    CC=/path/to/staging_dir_armeb/bin/armeb-linux-uclibc-gcc \
    LD=/path/to/staging_dir/armeb/bin/armeb-linux-uclibc-ld \
    --prefix=/path/to/staging_dir_armeb
  make
  make install

- this will put everything you need under the staging_dir_armeb

- if you don't need any shared libraries, you can just specify the
  correct compiler when doing a build. You could also probably just
  statically link them.

Making batch changes to the NSLU's
--------------
Logging in to the NSLU's one at a time sucks. I put together two
'expect' scripts to make it easier to deal with.  Expect can be
obtained with `apt-get expect`. 

ssh.exp <user> <passw> <host> <cmd>
- connect with provided credentials and execute cmd. cmd can be
  quoted.
- example: 
  expect ssh.exp root nslu1.cs.jhu.edu the-root-password "touch test.txt; ls | grep test.txt; rm test.txt"

scp.exp <user> <passw> <host> <localSrc> <remoteDest>
- use scp to copy the file at localSrc to remoteDest on the remote
  host.
- example:
  expect scp.exp root nslu1.cs.jhu.edu the-root-password test.txt '/tmp/.'


