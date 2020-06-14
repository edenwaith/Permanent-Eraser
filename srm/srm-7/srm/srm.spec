Name: srm
Version: 1.2.8
Release: 1
License: X11
URL: http://srm.sourceforge.net
Group: Applications/File
Vendor: Matt Gauthier <elleron@attbi.com>
Packager: %{vendor}

Prefix: /usr
Prefix: /usr/local
Buildroot: /tmp/%{name}.buildroot
Source: %{name}-%{version}.tar.gz

Summary: srm (secure rm) is a command-line compatible rm(1) which destroys file contents before unlinking.

%description
This is srm, a secure replacement for rm(1). Unlike the standard rm,
it overwrites the data in the target files before unlinking them.
This prevents command-line recovery of the data by examining the raw
block device. It may also help frustrate physical examination of the
disk, although it's unlikely that it completely protects against this
type of recovery.
%prep
%setup
./configure

%build
make

%install
make prefix=%{buildroot}/usr install

%clean
rm -rf %{buildroot}
make clean

%files
%attr(-, root, root) /usr/bin/srm
%attr(-, root, root) %doc /usr/man/man1/*

