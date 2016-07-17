all:

CURL = curl
WGET = wget
GIT = git

updatenightly: local/bin/pmbp.pl
	perl local/bin/pmbp.pl --update
	$(GIT) add config

## ------ Setup ------

deps: git-submodules pmbp-install

git-submodules:
	$(GIT) submodule update --init

local/bin/pmbp.pl:
	mkdir -p local/bin
	$(WGET) -O $@ https://raw.github.com/wakaba/perl-setupenv/master/bin/pmbp.pl
pmbp-upgrade: local/bin/pmbp.pl
	perl local/bin/pmbp.pl --update-pmbp-pl
pmbp-update: git-submodules pmbp-upgrade
	perl local/bin/pmbp.pl --update
pmbp-install: pmbp-upgrade
	perl local/bin/pmbp.pl --install \
            --create-perl-command-shortcut perl \
            --create-perl-command-shortcut prove

## ------ Tests ------

PROVE = ./prove

test: test-deps test-main

test-deps: deps
	./perl -MTest::Builder -e 'print $Test::Builder::VERSION, "\n"'
	./perl -MTest::More -e 'print $Test::More::VERSION, "\n"'

test-main:
	$(PROVE) t/*.t
