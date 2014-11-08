EXTRA_DIST = AUTHORS COPYING ChangeLog INSTALL NEWS README TODO srm.spec.in test.sh srm.sln srm.vcproj
SUBDIRS = lib src doc win

rpm: dist
	rpmbuild -tb $(distdir).tar.gz

maintainer-clean-local:
	rm -f config.h.in configure depcomp install-sh missing Makefile.in */Makefile.in *.tst srm-*.tar.gz
	find . -name '*~' -exec rm -f {} ';'
	rm -rf Debug Release srm.ncb srm.suo srm.vcproj.*

test:	all
	sh test.sh
