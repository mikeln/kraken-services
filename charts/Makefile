CHARTS := $(shell ls -dm */ | sed 's/,//g' | sed 's/cnct-atlas//g' | sed 's/\///g')

.PHONY: clean all package makepath copy index sync acl
all: package makepath copy index sync acl

package: ; $(foreach chart,$(CHARTS),(helm package $(chart)) &&) :

makepath:
	@mkdir -p cnct-atlas

copy:
	@mv *.tgz cnct-atlas/

index:
	@helm repo index cnct-atlas http://atlas.cnct.io

sync:
	@gsutil rsync ./cnct-atlas gs://atlas.cnct.io

acl:
	@gsutil -m acl set -R -a public-read gs://atlas.cnct.io

clean:
	@rm -rf cnct-atlas