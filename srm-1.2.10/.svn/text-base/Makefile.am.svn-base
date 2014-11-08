EXTRA_DIST = AUTHORS COPYING ChangeLog INSTALL NEWS README TODO srm.spec.in test.sh srm.sln srm.vcproj
SUBDIRS = lib src doc

rpm: dist
	rpmbuild -tb $(distdir).tar.gz
	mv ~/src/rpm/RPMS/i386/srm* .

cvsclean:
	-make distclean
	rm -rf autom4te.cache
	rm -f config.h.in configure depcomp install-sh missing stamp-h.in Makefile.in */Makefile.in
	find . -name '*~' -exec rm -f {} ';'

test:	all
	sh test.sh
